<?php

namespace DC4Lan\Stats
{

    class StatsFields
    {
        const localtime = 0;
        const uptime = 1;
        const shared = 2;
        const sharedFiles = 3;
        const users = 4;
        const passiveUsers = 5;
        const awayUsers = 6;
        const extendedAwayUsers = 7;
        const uploadSpeed = 8;
        const downloadSpeed = 9;
        const slots = 10;
        const freeSlots = 11;
        const hubs = 12;
        const queueCalls = 13;
        const sendCalls = 14;
        const recvCalls = 15;
        const queueBytes = 16;
        const sendBytes = 17;
        const recvBytes = 18;
        const sSearch = 19;
        const sTTHSearch = 20;
        const sStoppedSearch = 21;
        const searchs = 21;
        const tthSearchs = 22;
        const activeSearchs = 23;
        const passiveSearchs = 24;
        const chatMessages = 25;
        const privateMessages = 26;
        const botPrivateMessages = 27;
        const bloomReceived = 28;
        const infoUpdates = 29;
        const passiveResults = 30;
        const activeConnectionRequests = 31;
        const passiveConnectionRequests = 32;
        const passiveNatRequests = 33;
        const incomingConnections = 34;

        static protected $fieldNames = array(
            'localtime',
            'uptime',
            'shared',
            'sharedFiles',
            'users',
            'passiveUsers',
            'awayUsers',
            'extendedAwayUsers',
            'uploadSpeed',
            'downloadSpeed',
            'slots',
            'freeSlots',
            'hubs',
            'queueCalls',
            'sendCalls',
            'recvCalls',
            'queueBytes',
            'sendBytes',
            'recvBytes',
            'sSearch',
            'sTTHSearch',
            'sStoppedSearch',
            'searchs',
            'tthSearchs',
            'activeSearchs',
            'passiveSearchs',
            'chatMessages',
            'privateMessages',
            'botPrivateMessages',
            'bloomReceived',
            'infoUpdates',
            'passiveResults',
            'activeConnectionRequests',
            'passiveConnectionRequests',
            'passiveNatRequests',
            'incomingConnections'
        );

        public static function getFieldName($fieldId)
        {
            if (isset(self::$fieldNames[$fieldId])) {
                return self::$fieldNames[$fieldId];
            }

            return null;
        }

        public static function getFields()
        {
            return self::$fieldNames;
        }
    }

    class Parser
    {
        protected $config =
            array(
                'delimiter' => ',',
            );

        protected $modifiers =
            array(
            );

        protected $values = array();

        public function __construct($file)
        {
            $this->values = $this->loadAndReadFile($file);

            foreach ($this->modifiers as $field => $function) {
                if (method_exists($this, $function)) {
                    call_user_func(array($this, $function), $field);
                }
            }

            if ($this->isInDowntimeStatus('uptime')) {
                foreach (array_keys($this->values) as $field) {
                    if ($this->values[$field] > 0) {
                        $this->values[$field] = 0;
                    }
                }
            }
        }

        public function getValue($field)
        {
            if (isset($this->values[$field])) {
                return array_combine(array($field), array($this->values[$field]));
            }

            return null;
        }

        public function getAll()
        {
            return $this->values;
        }

        /**
         * Carga el fichero origen CSV y lo convierte a JSON.
         * @param string $file Ruta al fichero origen
         *
         * @throws CSVParsingException
         * @return array Array de items codificados en JSON.
         */
        protected function loadAndReadFile($file)
        {
            $content = fopen($file, 'r');
            $config = $this->config;

            $fieldDelimiter = $config['delimiter'];

            try {
                $output = array();
                $this->setTail($content);

                while (($csvData = fgetcsv($content, 0, $fieldDelimiter)) !== false) {
                    $output = array_combine(StatsFields::getFields(), array_values($csvData));
                }
            } catch (\Exception $e) {
                if ($content !== false) {
                    fclose($content);
                }

                return null;
            }

            if ($content !== false) {
                fclose($content);
            }

            return $output;
        }

        protected function isInDowntimeStatus($field)
        {
            $downtime = false;
            $value = $this->values[$field];
            $localtime = time();
            $timefile = $this->values['localtime'];

            $file = "/usr/share/adchpp-lan-9999/scripts/FL_DataBase/" . $field . ".last.txt";
            $data = array();
            if (file_exists($file)) {
                $data = json_decode(file_get_contents($file), true);
                if ($localtime >= ($timefile + 120) && $value == $data[$field]) {
                    $this->dumpDowntimeEvent();
                    $this->values[$field] = 0;
                    $downtime = true;
                }
            }
            $data[$field] = $value;
            $data['localtime'] = $timefile;

            file_put_contents($file, json_encode($data));

            return $downtime;
        }

        protected function dumpDowntimeEvent() {
            $file = "/usr/share/adchpp-lan-9999/scripts/FL_DataBase/" . $this->values['localtime'] . ".downtime.dump.txt";
            if (!file_exists($file)) {
                file_put_contents($file, json_encode($this->values));
            }
        }

        protected function setTail($fileHandler) {
            $pointer = -2;
            do {
                fseek($fileHandler, $pointer--, SEEK_END);
                $character = fgetc($fileHandler);
            } while ($character != "\n");
        }
    }
}
