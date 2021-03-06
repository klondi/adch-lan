import pyadchpp as a
import re

def receiveHandler(client, cmd, ok, filter, callback):
    if not ok:
        return ok
    
    if cmd.getCommand() != filter:
        return ok
    
    return callback(client, cmd, ok)
    
def handleCommand(core, filter, callback):
    cm = core.getClientManager()
    return cm.signalReceive().connect(lambda client, cmd, ok: receiveHandler(client, cmd, ok, filter, callback))

def dump(c, code, msg):
    answer = a.AdcCommand(a.AdcCommand.CMD_STA, a.AdcCommand.TYPE_INFO, a.AdcCommand.HUB_SID)
    answer.addParam(str(a.AdcCommand.SEV_FATAL) + str(code)).addParam(msg)
    c.send(answer)
    c.disconnect(0)
    return False

def fallbackdict(dict):
    def __init__(self, fallback):
        self.fallback = fallback
        
    def __getitem__(self, key):
        try:
            return super(fallbackdict, self).__getitem__(self, key)
        except KeyError:
            return self.fallback.__getitem__(self, key)
   
class InfVerifier(object):
    BASE32_CHARS = "[2-7a-zA-Z]"
    any = re.compile(".*")
    nonempty = re.compile(".+")
    sta_code = re.compile("[0,1,2][0-9]{2}")
    sid = re.compile(BASE32_CHARS + "{4}")
    tth = re.compile(BASE32_CHARS + "{39}")
    integer = re.compile("[\\-0-9]+")
    base32 = re.compile(BASE32_CHARS + "+");
    boolean = re.compile("[1]?")
    
    fields = {
        a.AdcCommand.CMD_INF : {
            "ID" : tth,
            "PD": tth,
            "I4": re.compile("(([0-1]?[0-9]{1,2}[.])|(2[0-4][0-9][.])|(25[0-5][.])){3}(([0-1]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))"),
            "I6": re.compile("[0-9a-fA-F:]+"), # This could be better
            "U4": integer,
            "U6": integer,
            "SS": integer,
            "SF": integer,
            "US": integer,
            "DS": integer,
            "SL": integer,
            "AS": integer,
            "AM": integer,
            "NI": nonempty,
            "HN": integer,
            "HR": integer,
            "HO": integer,
            "OP": boolean,
            "AW": re.compile("1|2"),
            "BO": boolean,
            "HI": boolean,
            "HU": boolean,
            "SU": re.compile("[0-9A-Z,]+"),
        },
        
        a.AdcCommand.CMD_MSG : {
            "PM": sid,
            "ME": boolean,
        },
         
        a.AdcCommand.CMD_SCH : {
            "AN": nonempty,
            "NO": nonempty,
            "EX": nonempty,
            "LE": integer,
            "GE": integer,
            "EQ": integer,
            "TO": nonempty,
            "TY": re.compile("1|2"),
            "TR": tth,
        },
        
        a.AdcCommand.CMD_RES : {
            "FN": nonempty,
            "SI": integer,
            "SL": integer,
            "TO": nonempty,
            "TR": tth,
            "TD": integer,
        }
    }
    
    params = {
        a.AdcCommand.CMD_STA: (sta_code, any),
        a.AdcCommand.CMD_MSG: (any,),
        a.AdcCommand.CMD_CTM: (any, integer, any),
        a.AdcCommand.CMD_RCM: (any, any),
        a.AdcCommand.CMD_PAS: (base32,)
    }
 
    def __init__(self, core, succeeded, failed):
        self.succeeded = succeeded or (lambda client: True)
        self.failed = failed or dump
        self.core = core
        self.inf = handleCommand(core, a.AdcCommand.CMD_INF, self.validate)
        
    def validate(self, c, cmd, ok):
        if ok and cmd.getCommand() in self.params:
            ok &= self.validateParam(c, cmd, self.params[cmd.getCommand()])
        
        if ok and cmd.getCommand() in self.fields:
            ok &= self.validateFields(c, cmd, self.fields[cmd.getCommand()])
        
        return ok & self.succeeded(c)

    def validateParam(self, c, cmd, params):
        if len(cmd.getParameters()) < len(params):
            return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "Too few parameters for " + cmd.getCommand())
        
        for i, param in enumerate(params):
            if not param.match(cmd.getParam(i)):
                return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, cmd.getParam(i) + " doesn't match " + param)
        return True
    
    def validateFields(self, c, cmd, fields):
        for field in cmd.getParameters():
            if field[0:2] in fields:
                r = fields[field[0:2]]
                if not r.match(field[2:]):
                    return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, field + " doesn't match " + str(r))
        return True
    
class PasswordHandler(object):
    def __init__(self, core, getPassword, succeeded, failed):
        self.getPassword = getPassword or (lambda nick, cid: None)
        self.succeeded = succeeded or (lambda client: True)
        self.failed = failed or dump
        
        self.inf = handleCommand(core, a.AdcCommand.CMD_INF, self.onINF)
        self.pas = handleCommand(core, a.AdcCommand.CMD_PAS, self.onPAS)
        
        self.cm = core.getClientManager()
        
        self.salt = core.getPluginManager().registerPluginData()
        
    def onINF(self, e, cmd, ok):
        if not ok:
            return ok
        
        c = e.asClient()
        if not c or c.getState() != a.Client.STATE_IDENTIFY:
            return True
        
        foundn, nick = cmd.getParam("NI", 0)
        foundc, cid = cmd.getParam("ID", 0)
        
        if not foundn or not foundc:
            return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")

        password = self.getPassword(nick, cid)
        if not password:
            return True
        
        if not self.cm.verifyINF(c, cmd):
            return False
        
        c.setPluginData(self.salt, (self.cm.enterVerify(c, True), password))
        
        return False
    
    def onPAS(self, e, cmd, ok):
        if not ok:
            return ok
        
        c = e.asClient()
 
        if c.getState() != a.Client.STATE_VERIFY:
            return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
        
        salt, password = c.getPluginData(self.salt)
        
        if not salt:
            return self.failed(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
        
        c.setPluginData(self.salt, None)
        
        cid = c.getCID()
        nick = c.getField("NI")
        
        if not self.cm.verifyPassword(c, password, salt, cmd.getParam(0)):
            return self.failed(c, a.AdcCommand.ERROR_BAD_PASSWORD, "Invalid password")

        self.cm.enterNormal(c, True, True)
        
        self.succeeded(c)
        return False
