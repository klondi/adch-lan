%module pyadchpp

%{
// Python pollution
#undef socklen_t
%}

%typemap(in) std::tr1::function<void (adchpp::Client&)> {
	$1 = PyHandle($input, false);
}
%typemap(in) std::tr1::function<void (adchpp::Client&, adchpp::AdcCommand&)> {
	$1 = PyHandle($input, false);
}
%typemap(in) std::tr1::function<void (adchpp::Client&, int)> {
	$1 = PyHandle($input, false);
}
%typemap(in) std::tr1::function<void (adchpp::Client&, const std::string&)> {
	$1 = PyHandle($input, false);
}
%typemap(in) std::tr1::function<void (adchpp::Client&, adchpp::AdcCommand&, int&)> {
	$1 = PyHandle($input, false);
}

%include "adchpp.i"

%init%{
	PyEval_InitThreads();
%}
%{
struct PyGIL {
	PyGIL() { state = PyGILState_Ensure(); }
	~PyGIL() { PyGILState_Release(state); }
	PyGILState_STATE state;
};

struct PyHandle {
	PyHandle(PyObject* obj_, bool newRef) : obj(obj_) { if(!newRef) Py_XINCREF(obj); }
	PyHandle(const PyHandle& rhs) : obj(rhs.obj) { Py_XINCREF(obj); }
	
	PyHandle& operator=(const PyHandle& rhs) { 
		Py_XDECREF(obj);
		obj = rhs.obj;
		Py_XINCREF(obj);
		return *this;
	}
	~PyHandle() { Py_XDECREF(obj); }
	
	PyObject* operator ->() { return obj; }
	operator PyObject*() { return obj; }
	
	void operator()() {
		PyGIL gil;
		PyHandle ret(PyObject_Call(obj, PyTuple_New(0), 0), true);
	}
	
	void operator()(adchpp::Client& c) {
		PyGIL gil;
		PyObject* args(PyTuple_New(1));
		
		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&c), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyHandle ret(PyObject_Call(obj, args, 0), true);
	}

	void operator()(adchpp::Client& c, const std::string& str) {
		PyGIL gil;
		PyObject* args(PyTuple_New(2));
		
		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&c), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyTuple_SetItem(args, 1, PyString_FromString(str.c_str()));
		
		PyHandle ret(PyObject_Call(obj, args, 0), true);
	}
	
	void operator()(adchpp::Client& c, int i) {
		PyGIL gil;
		PyObject* args(PyTuple_New(2));
		
		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&c), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyTuple_SetItem(args, 1, PyInt_FromLong(i));
		
		PyHandle ret(PyObject_Call(obj, args, 0), true);
	}

	void operator()(adchpp::Client& c, adchpp::AdcCommand& cmd) {
		PyGIL gil;
		PyObject* args(PyTuple_New(2));
		
		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&c), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyTuple_SetItem(args, 1, SWIG_NewPointerObj(SWIG_as_voidptr(&cmd), SWIGTYPE_p_adchpp__AdcCommand, 0 |  0 ));
		
		PyHandle ret(PyObject_Call(obj, args, 0), true);
	}

	void operator()(adchpp::Client& c, adchpp::AdcCommand& cmd, int& i) {
		PyGIL gil;
		PyObject* args(PyTuple_New(3));
		
		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&c), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyTuple_SetItem(args, 1, SWIG_NewPointerObj(SWIG_as_voidptr(&cmd), SWIGTYPE_p_adchpp__AdcCommand, 0 |  0 ));
		PyTuple_SetItem(args, 2, PyInt_FromLong(i));
		
		PyHandle ret(PyObject_Call(obj, args, 0), true);
		
		if(PyInt_Check(ret)) {
			i |= static_cast<int>(PyInt_AsLong(ret));
		}
	}

private:
	PyObject* obj;
};
%}
