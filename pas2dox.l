%{
// ---------------------------------------------------------------------------
// File:   pas2dox.lex
// Author: (c) 2024 by Jens Kallup - paule32.
//         all rights reserved.
//
// Permission to use, copy, modify, and distribute this software and its
// documentation under the terms of the GNU General Public License is hereby
// granted. No representations are made about the suitability of this software
// for any purpose. It is provided "as is" without express or implied warranty
// See the GNU General Public License for more details.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// we support only GNU-C/C++ compilers ...
// ---------------------------------------------------------------------------
#if !defined(__GNUC__)
#error only GNU-C/C++ Compiler supported.
#endif

// ---------------------------------------------------------------------------
// the minimum requirements is a GNU C++ compiler ...
// ---------------------------------------------------------------------------
#if !defined(__cplusplus)
#error C++ Compiler required.
#endif

// ---------------------------------------------------------------------------
// a msys2 development environment is needed for this Application.
// MSYS2 is a set of tool chain for Microsot Windows OS.
// ---------------------------------------------------------------------------
#if defined(__MINGW32__) || defined(__MINGW64__)
# include <io.h>
# include <windows.h>
# include <tchar.h>
# include <strsafe.h>
#endif

// ---------------------------------------------------------------------------
// standard header stuff ...
// ---------------------------------------------------------------------------
# include <stdio.h>
# include <stdlib.h>
# include <string.h>        // memset
# include <sys/types.h>

// ---------------------------------------------------------------------------
// c++ header prototype's/signature's:
// ---------------------------------------------------------------------------
# include <iostream>        // std c++ signatures
# include <string>
# include <cstdlib>
# include <cstring>
# include <sstream>
# include <istream>
# include <fstream>
# include <cstdio>
# include <libintl.h>       // localization
# include <regex>           // regular expressions
# include <cstdlib>
# include <cstddef>
# include <ctime>
# include <list>            // list array
# include <vector>
# include <unordered_map>
# include <map>
# include <any>
# include <filesystem>
# include <memory>
# include <functional>      // std::function
# include <codecvt>         // wstr to str
# include <locale>
# include <iomanip>
# include <exception>       // exception handler's
# include <stdexcept>

// ---------------------------------------------------------------------------
// boost library header files ...
// ---------------------------------------------------------------------------
# include <boost/program_options.hpp>
# include <boost/exception/all.hpp>

# include <boost/throw_exception.hpp>
# include <boost/lexical_cast.hpp>
# include <boost/core/verbose_terminate_handler.hpp>

# include <boost/locale.hpp>

// ---------------------------------------------------------------------------
// loggin specified header files ...
// ---------------------------------------------------------------------------
# include <plog/Log.h>
# include <plog/Initializers/RollingFileInitializer.h>

# include <inicpp.h>        // .ini files
# include <zlib.h>          // decompress locale

// ---------------------------------------------------------------------------
// asmjit - remote assembly for c++
// ---------------------------------------------------------------------------
# include <x86.h>

// ---------------------------------------------------------------------------
// used namespace ...
// ---------------------------------------------------------------------------
using namespace boost::program_options;
using namespace asmjit;             // remote assembly
using namespace x86;                // x86 cpu
using namespace plog;               // logging
using namespace ini;                // .ini
using namespace std;                // c++ std container

// ---------------------------------------------------------------------------
// application stuff (name, locale ...
// ---------------------------------------------------------------------------
const std::string ApplicationVersion = "0.51";
const std::string ApplicationDate    = __DATE__;

const std::string ApplicationLogFile = "pas2dox.log";
const std::string ApplicationIniFile = "pas2dox.ini";
const std::string ApplicationExeFile = "pas2dox.exe";

// ---------------------------------------------------------------------------
// global source code streams ...
// ---------------------------------------------------------------------------
std::stringstream g_cModulesCode;   // unit
std::stringstream g_cProgramCode;   // program
std::stringstream g_cLibraryCode;   // library

// ---------------------------------------------------------------------------
// application localization ...
// ---------------------------------------------------------------------------
#if defined(__MINGW32__) || defined(__MINGW64__)
LCID g_bLocalesSytemLCID;
LCID g_bLocalesApplicationLCID;
# else
std::locale g_bLocalesSytem;
std::locale g_bLocalesApplication;
#endif

// ---------------------------------------------------------------------------
// global application variables ...
// ---------------------------------------------------------------------------
bool g_cUsesStart = false;          // source code: uses
bool g_cUsesEnd   = false;

std::string g_bCodepageApplication; // ANSI or OEM
ini::IniFile  myini;

// ---------------------------------------------------------------------------

FILE * OUTPUT  = NULL;
FILE * logFile = NULL;              // todo: assembly output

// ---------------------------------------------------------------------------
// sanity check of some (pre) defined macros ...
// ---------------------------------------------------------------------------
#ifndef  EXIT_FAILURE
# define EXIT_FAILURE 1
# define EXIT_SUCCESS 0
#endif

// ---------------------------------------------------------------------------
// exception class, to reduce use size of code - instead conditional
// spagetty code ...
// ---------------------------------------------------------------------------
# define CreatePascalException(name)                                \
class  EP_Exception_ ## name: public std::exception {               \
public:EP_Exception_ ## name (const char* message)  :               \
errorMessage(message) {} virtual const char* what() const throw() { \
return errorMessage.c_str(); } private: std::string errorMessage; }
// ---------------------------------------------------------------------------
CreatePascalException (SyntaxError);
CreatePascalException (Pascal);
CreatePascalException (ExitHelp);
CreatePascalException (ExitFailure);
CreatePascalException (TranspilerMode);

// ---------------------------------------------------------------------------
// SE_ = string error placeholders, to kill duplicate strings ...
// ---------------------------------------------------------------------------
constexpr std::string_view SE_context_transpiller = "transpiller";
constexpr std::string_view SE_context_syntaxError = "syntax error";
constexpr std::string_view SE_context             = "context: ";
constexpr std::string_view SE_convert_fail        = "converting fail";

constexpr std::string_view SE_syntax_keyword      = "uses is a keyword, and can not use as ID.";
constexpr std::string_view SE_syntax_expect_semi  = "expect ;";
constexpr std::string_view SE_syntax_expect_comma = "expect ,";

bool g_bDebugMode     = false;      /// In Debug Mode

// ---------------------------------------------------------------------------
// transpiller mode throw ...
// ---------------------------------------------------------------------------
BOOST_NORETURN BOOST_NOINLINE
void throw_TranspilerMode(
    std::string err,
    boost::source_location const & loc) {
    
    std::stringstream ss;
    ss <<  "Error: "
       <<  dec << yylineno << ": "
       <<  err << endl     << "   "
       <<  SE_context
       <<  SE_context_transpiller;
    
    if (g_bDebugMode) {
        PLOGE << SE_convert_fail;
    }

    boost::throw_with_location(
    EP_Exception_TranspilerMode( ss.str().c_str()), loc);
}
BOOST_NORETURN BOOST_NOINLINE
void throw_SyntaxError(
    std::string err,
    boost::source_location const & loc) {
    
    std::stringstream ss;
    ss <<  "Error: "
       <<  dec << yylineno << ": "
       <<  err << endl     << "   "
       <<  SE_context
       <<  SE_context_syntaxError;
    
    if (g_bDebugMode) {
        PLOGE << SE_convert_fail;
    }

    boost::throw_with_location(
    EP_Exception_SyntaxError( ss.str().c_str()), loc);
}

// ---------------------------------------------------------------------------
// asmjit initialize ...
// ---------------------------------------------------------------------------
void init_asmjit()
{
    JitRuntime rt;            // Runtime specialized for JIT code execution.
    CodeHolder code;          // Holds code and relocation information.

    code.init(
    rt.environment () ,       // Initialize code to match the JIT environment.
    rt.cpuFeatures () );

    x86::Compiler cc(&code);  // Create and attach x86::Compiler to code.
}

// ---------------------------------------------------------------------------
// Type of function
// ---------------------------------------------------------------------------
enum func_type {
    NORMAL,       ///< Normal
    CONSTRUCTOR,  ///< Constructor function
    DESTRUCTOR,   ///< Destructor function
};

// ---------------------------------------------------------------------------
// type of transpiler (converter) mode ...
// ---------------------------------------------------------------------------
enum g_bTranspilerModeType {
    tm_UNKNOWN = 0,
    tm_LIBRARY,
    tm_PROGRAM,
    tm_UNIT
};
g_bTranspilerModeType g_bTranspilerMode;

// ---------------------------------------------------------------------------
// Type Conversion
// ---------------------------------------------------------------------------
struct type_conv
{
    char m_pascal_type[15];
    char m_c_type[15];
};

type_conv type_conversion[] = {
    { "boolean",   "bool"           },
    { "shortint",  "signed char"    },
    { "byte",      "char*"          },
    { "smallint",  "short"          },
    { "word",      "unsigned short" },
    { "integer",   "int"            },
    { "longint",   "long"           },
    { "single",    "float"          },
    { "double",    "double"         },
    { "self",      "this"           },
};

// ---------------------------------------------------------------------------
// Operator Conversion
// ---------------------------------------------------------------------------
struct op_conv
{
    char m_pascal_op[4];
    char m_c_op[3];
};

// ---------------------------------------------------------------------------
// \note duplicated operators for bitwise and logical operations.
//
// biwise operators have a higher precedence, than logical, so
//
// if x > 0 and x < 10 then...  will use bitwise operators
// if (x > 0) and (x < 10) then...  will use logical operators
// ---------------------------------------------------------------------------
op_conv operator_conversion[] = {
    { ".",   "::" },     ///< Scope Resolution
    { "not",  "~" },     ///< Bitwise negation
    { "@",    "&" },     ///< Address
    { "^",    "*" },     ///< De-Reference
    { "/",    "/" },     ///< Floating point division
    { "div",  "/" },     ///< Integer Division
    { "mod",  "^" },     ///< Modulus
    { "shl", "<<" },     ///< Left bitwise shift
    { "shr", ">>" },     ///< Right bitwise shift
    { "=",   "==" },     ///< Equal to
    { "<>",  "!=" },     ///< Not Equal to
    { "and",  "&" },     ///< Bitwise AND
    { "or",   "|" },     ///< Bitwise OR
    { "xor",  "^" },     ///< Bitwise XOR
    { "not",  "!" },     ///< Logical NOT
    { "and", "&&" },     ///< logical AND
    { "or",  "||" },     ///< Logical OR
    { ":=",   "=" },     ///< Simple Assignment
};

// ---------------------------------------------------------------------------
// Convert from Pascal type to C++ type
// ---------------------------------------------------------------------------
void Convert_Type(string& pText)  ///< Type to be converted
{
    type_conv* p;

    string str = pText;

    for(int  i = 0; i < str.size(); i++)
    str[i] = tolower(str[i]); 

    int count = sizeof(type_conversion) / sizeof(type_conv);

    for (int i = 0; i < count; i++) {
        p = &type_conversion[i];

        // have we found the pascal type in our table?
        if (str == p->m_pascal_type) {
            // convert to c++ type
            pText = p->m_c_type;
        }
    }
}

// ---------------------------------------------------------------------------
// Remove spaces
// ---------------------------------------------------------------------------
void RemoveSpaces(string& pText)  ///< String to work on
{
    size_t pos = string::npos;

    while(true) {
        pos = pText.find(" ", 0);

        if (pos == string::npos)
        break;

        pText.replace(pos, 1, "");
    }
}

// ---------------------------------------------------------------------------
// Class Information
// ---------------------------------------------------------------------------
class class_info
{
public:
    class_info();
    class_info(
        string name,
        string parent,
        string parent2,
        string var,
        string type);

    string sName;        /// Class Name
    string sParent;      /// Parent Class
    string sParent2;     /// Second Parent Class

    string sVar;         /// Class Variable
    string sType;        /// Class Type
};

class_info::class_info()
{
    sName    = "";
    sParent  = "";
    sParent2 = "";
    sVar     = "";
    sType    = "";
}

class_info::class_info(
    string name,    ///< Class Name
    string parent,  ///< Parent Class
    string parent2, ///< Second Parent Class
    string var,     ///< Class Variable
    string type)    ///< Class Type
{
    sName = name;
    sParent = parent;
    sParent2 = parent2;
    sVar = var;
    sType = type;
}

// ---------------------------------------------------------------------------
// Parameter Information
// ---------------------------------------------------------------------------
class param_info
{
public:
    // Copy constructor
    param_info(const param_info& obj)  { *this = obj; }

    // Assignment operator
    param_info& operator = (const param_info& obj);

    param_info();
    param_info(
        string type,
        string name,
        string comment,
        string def,
        bool   c,
        bool   v,
        bool   o,
        bool array);

    string sType;        /// Parameter Name
    string sName;        /// Parameter Type
    string sDefault;     /// Default Value
    string sComment;     /// Associated Comment
    
    bool bConst;         /// Const Parameter
    bool bVar;           /// Var Parameter
    bool bOut;           /// Out Parameter
    bool bArray;         /// Array Parameter
};

param_info& param_info::operator=(const param_info& obj)
{
    sType    = obj.sType;
    sName    = obj.sName;
    sDefault = obj.sDefault;
    sComment = obj.sComment;

    bConst   = obj.bConst;
    bVar     = obj.bVar;
    bOut     = obj.bOut;
    bArray   = obj.bArray;

    return *this;
}

param_info::param_info()
{
    sType    = "";
    sName    = "";
    sComment = "";
    bConst   = false;
    bVar     = false;
    bOut     = false;
    bArray   = false;
}

param_info::param_info(
    string type,
    string name,
    string comment,
    string def,
    bool   c,
    bool   v,
    bool   o,
    bool   array)
{
    sType    = type;
    sName    = name;
    sComment = comment;
    sDefault = def;
    bConst   = c;
    bVar     = v;
    bOut     = o;
    bArray   = array;
}

// ---------------------------------------------------------------------------
// Function Information
// ---------------------------------------------------------------------------
class func_info
{
public:
    func_info();
    func_info(
        string    aclass,
        string    name,
        string    ret,
        func_type ft);

    string sClass;               ///< Associated Class
    string sName;                ///< Function Name
    string sRet;	               ///< Return Type

    func_type eFuncType;         ///< Function type

    // -----------------------------------------------------------------------
 	// Pure virtual function that defines how this function should be
    // formatted in Pascal.
    // -----------------------------------------------------------------------
    virtual void pascalize() = 0;
};

func_info::func_info()
{
    sClass    = "";
    sName     = "";
    sRet      = "";

    eFuncType = NORMAL;
}

func_info::func_info(string aclass, string name, string ret, func_type ft)
{
    sClass    = aclass;
    sName     = name;
    sRet      = ret;

    eFuncType = ft;
}

/// Normal Function
class func_info_typedef : public func_info
{
public:
    func_info_typedef(){}
    func_info_typedef(
        string aclass,
        string name,
        string ret,
        func_type ft):
        func_info(aclass, name, ret, ft) {}

    virtual void pascalize(){
        fprintf(OUTPUT,
        "typedef %s (*%s)(", sRet != ""
        ? sRet.c_str() : "void", sName.c_str());
	};
};

class func_info_variable : public func_info
{
public:
    func_info_variable(){}
    func_info_variable(
        string    aclass,
        string    name,
        string    ret,
        func_type ft):
        func_info(aclass, name, ret, ft) {}
    virtual void pascalize(){
        fprintf(OUTPUT, "%s (*%s)(", sRet != ""
        ? sRet.c_str() : "void", sName.c_str());
	};
};


// ---------------------------------------------------------------------------
// Property Information
// ---------------------------------------------------------------------------
class prop_info
{
public:
    prop_info();
    prop_info(string name, string type);

    string sName;                /// Property Name
    string sType;                /// Property Type

    string sRead;                /// Read Value
    string sWrite;               /// Write Value
    string sDefault;             /// Default Value

    bool bRead;                  /// Assign read property
};

prop_info::prop_info()
{
    sName = "";
    sType = "";
}

prop_info::prop_info(string name, string type)
{
    sName = name;
    sType = type;
}

// ---------------------------------------------------------------------------
// Array / Set Information
// ---------------------------------------------------------------------------
class array_info
{
  public:
    array_info();
    array_info(
        string name,
        string type,
        int    size,
        string def);

    string sName;           ///< Array Name
    string sType;           ///< Array Type
    int nSize;              ///< Array Size
    string sDefault;        ///< Default Values
};

array_info::array_info()
{
  sName = "";
  sType = "";
  nSize = 0;
  sDefault = "";
}

array_info::array_info(
    string name,
    string type,
    int    size,
    string def)
{
  sName = name;
  sType = type;
  nSize = size;
  sDefault = def;
}

// ---------------------------------------------------------------------------
func_info * pFunc     = nullptr;

class_info* pClass    = nullptr;
prop_info * pProperty = nullptr;
array_info* pArray    = nullptr;

list<param_info> lstParams;        /// List Of Parameters
list<string>     g_lstComments;    /// List Of Comments
list<param_info> g_lstParams;      /// List Of Parameters
list<int>        g_lstSize;        /// List of Integers for multi dimensional arrays

std::string g_defaultvalue;
std::string g_processtype ;

list<string> g_lParamType;         /// Parameter Type

unsigned int g_nNamespaces = 0;
unsigned int g_nBegins = 0;

// Sections
bool g_bClassBody         = false;  /// In Class Body
bool g_bFuncBody          = false;  /// In Function Body
bool g_bType              = false;  /// In Type Section
bool g_bImplementation    = false;  /// In Implementation Section
bool g_bIgnoreTypeSection = false;  /// Ignoring type section
bool g_bConstSec          = false;  /// In a Const Section
bool g_bParams            = false;  /// Parameter List
bool g_bEnum              = false;  /// Enumeration
bool g_bCase              = false;  /// Case Statement
bool g_bInterface         = false;  /// Interface
bool g_bStructure         = false;  /// Structure
bool g_bVars              = false;  /// Vars
bool g_bSet               = false;  /// Sets
bool g_bIgnore            = false;  /// Ignore Section

bool g_bFom   = false;              /// Property Field Or Method
bool g_bConst = false;              /// Parameter is const
bool g_bVar   = false;              /// Var Parameter
bool g_bOut   = false;              /// Out Parameter
bool g_bArray = false;              /// Array parameter

list<string> g_lArrayStack;         /// For processing "array of array"s

string g_strTypedef     = "";       /// array or set
string g_strTypedefType = "";       /// array or set type
string g_strTypedefName = "";       /// array or set name

int g_nSize = 0;                    /// Array size
int g_bExitCode       = 0;          /// Application exit code - atexit()

bool g_bComments      = false;	    /// In a Comment Section

bool g_bKeepBody      = false;      /// Keep function body
bool g_bJavaDoc       = false;      /// JavaDoc Commenting
bool g_bAtEnd         = false;      /// At end of function parameters
bool g_bInterfaceOnly = false;      /// Process only 'Interface' section
bool g_bConvertBody   = false;      /// Convert function body to c++
bool g_bGenerateSa    = true;       /// Generate \sa clauses
bool g_bNamespace     = false;      /// Generate enclosing namespace

bool g_bIgnoreImplementation = false; /// Default is to include implementation

int g_nCommentCaller   = 0;         /// Inteligent returning from comments
int g_nDirectiveCaller = 0;         /// Inteligent returning from preprocessor directives
int g_nGeneralCaller   = 0;         /// Intelligent return

bool g_bCallback       = false;     /// In function typedef
bool g_bOutput         = false;


// ---------------------------------------------------------------------------
// Let's learn not to use macros in where inline function
// is more appropriate.
// ---------------------------------------------------------------------------
inline void OutputLog(const char *s, bool newline = true)
{
    if(!g_bDebugMode)
    return;

    for (; *s; ++s) {
        if(*s == '\n')
        fprintf(OUTPUT, "\\n"); else
        fputc(*s, OUTPUT);
    }

    if (newline)
    fputc('\n', OUTPUT);
}

// ---------------------------------------------------------------------------
/// std::string's concatenation can do it, too.
// ---------------------------------------------------------------------------
inline void OutputLog2(const char *s, const char *t){
	OutputLog(s,false);
	OutputLog(t);
}

// We leave them at this time
# define OutputLogNum(s, num) { if (g_bDebugMode) fprintf(OUTPUT, "%s %d\n", s, num); }
# define OutputLogHead()      { if (g_bDebugMode) fprintf(OUTPUT, "// line %d\n", __LINE__); }

// ---------------------------------------------------------------------------
// Convert Operator
// ---------------------------------------------------------------------------
void Convert_Op(
    string& pText,   ///< Operator to be converted
    bool    logical)    ///< Are we a logical operator?
{
  op_conv* p;

  // Return if we're not operating in function body conversion mode
  if (!g_bConvertBody)
    return;

  string str = pText;
//  std::transform (str.begin(),str.end(), str.begin(), tolower); #@@
	for(int i = 0; i < str.size(); i++)
		str[i] = tolower(str[i]); 
  int count = sizeof(operator_conversion) / sizeof(op_conv);

  for (int i = 0; i < count; i++)
  {
    p = &operator_conversion[i];

    // have we found a matching operator in our conversion table?
    if (str == p->m_pascal_op)
    {
      //OutputLog2("// original type = ", pText.c_str());
      //OutputLog2("// new type = ", p->m_c_op);
      // convert to a c++ operator
      pText = p->m_c_op;

      if (!logical)
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Display enumerations
// ---------------------------------------------------------------------------
void DisplayEnum(void)
{
  list<param_info>::iterator i;

  OutputLog("// DisplayEnum");

  for (i = lstParams.begin(); i != lstParams.end(); ++i)
  {
    string comm;

	fprintf(OUTPUT, "%s%s ",
      i->sName.c_str(),
      distance (i, lstParams.end()) == 1 ? "" : ",");

	while (!g_lstComments.empty())
	{
	  comm = g_lstComments.front();

      OutputLog2("//Got = ", comm.c_str());
	  if (comm == "*/")
	  {
	    fprintf(OUTPUT, "%s\n", comm.c_str());
		g_lstComments.pop_front();
	    break;
	  }

	  fprintf(OUTPUT, "%s", comm.c_str());

	  g_lstComments.pop_front();
	}

	fprintf(OUTPUT, "\n");

  }
}

// ---------------------------------------------------------------------------
// Remove Parameters From List
// ---------------------------------------------------------------------------
void RemoveParams()
{
    OutputLog("// clearing parameters");

    g_lstParams.clear();
    lstParams.clear();
}

// ---------------------------------------------------------------------------
// Process Parameter Types
// ---------------------------------------------------------------------------
void ProcessParameterType(const char* pText)
{
    list<param_info>::iterator i;

    // -----------------------------------------------------------------------
    // Loop through the parameters from the last type position
    // -----------------------------------------------------------------------
    for (i = lstParams.begin(); i != lstParams.end(); i++) {
        // and assign this type to those new parameters
        i->sType = pText;
        param_info p(
            pText,
            i->sName,
            i->sComment,
            g_defaultvalue,
            i->bConst,
            i->bVar,
            i->bOut,
            i->bArray);
        g_lstParams.push_back(p);
    }

    g_defaultvalue = "";
    g_processtype  = "";

    OutputLog("// Parameters cleared");
    lstParams.clear();
}

// ---------------------------------------------------------------------------
// Process Comments
// ---------------------------------------------------------------------------
void ProcessComment(void)
{
    // If we're not processing parameters at the moment
    // Then just output the text
    if (g_bParams == false) {
        OutputLog("// PC1");
        fprintf(OUTPUT, "%s", yytext);
    }   else {
        OutputLog2("// concatenating to lstParams.back().sComment ", yytext);

        // Add comment to the last item in the parameter list.
        if (!lstParams.empty()) {
            lstParams.back().sComment += yytext;
        }
    }
}

// ---------------------------------------------------------------------------
// Process end;
// ---------------------------------------------------------------------------
void ProcessEnd(void)
{
    OutputLog("// processing end\n");

    if (g_bCase) {
        fprintf(OUTPUT, "end;\n");
        g_bCase = false;
    }   else {
        fprintf(OUTPUT, "};\n");
    }

    // Tidy up if we're ending a class
    if (pClass) {
        //    delete pClass;
        pClass = NULL;
        g_bClassBody = false;
    }
}

// ---------------------------------------------------------------------------
// Output Inherited Class Details
// ---------------------------------------------------------------------------
void OutputInheritedClass(int ntype)
{
    OutputLogNum("// Inherited Class, type = ", ntype);
    
    if (g_bInterface) {
        // Treat interface like a class
        fprintf(OUTPUT, "class ");
        g_bInterface = false;
    }   else {
        fprintf(OUTPUT, "class ");
    }

    if (pClass->sParent != "") {
        fprintf(OUTPUT, "%s : public %s",
            pClass->sName  .c_str(),
            pClass->sParent.c_str());
    }   else {
        fprintf(OUTPUT, "%s",
            pClass->sName.c_str());
    }

    if (pClass->sParent2 != "") {
        fprintf(OUTPUT, ",%s",
            pClass->sParent2.c_str());
    }

    if (ntype == 0) {
        fprintf(OUTPUT, "\n{\n");

        // All members default to public
        fprintf(OUTPUT, "public:\n");

        g_bClassBody = true;
    }   else {
        fprintf(OUTPUT, ";\n");
    }
}

// ---------------------------------------------------------------------------
// Process Enumerations
// ---------------------------------------------------------------------------
void ProcessEnums(void)
{
    fprintf(OUTPUT, "enum %s\n{\n", pClass->sName.c_str());
    g_bParams = true;

    if (pClass) {
        delete pClass;
        pClass = NULL;
    }

    g_bEnum = true;
}

// ---------------------------------------------------------------------------
// Process Array
// ---------------------------------------------------------------------------
void ProcessArrays(void)
{
    fprintf(OUTPUT, "%s %s[%d] = { \n",
        pArray->sType.c_str(),
        pArray->sName.c_str(),
    g_nSize);

    g_bParams = true;

    if (pArray) {
        delete pArray;
        pClass = NULL;
    }

    g_bEnum = true;
}

// ---------------------------------------------------------------------------
void ProcessFunction(func_type ft, bool variable = false)
{
    // Process function or procedure

    if (pFunc)
    delete pFunc;

    pFunc = variable
    ? (func_info*)new func_info_variable
    : (func_info*)new func_info_typedef;
    
    pFunc->sRet = "";
    pFunc->eFuncType = ft;
}

// ---------------------------------------------------------------------------
// Display function params
// ---------------------------------------------------------------------------
void DisplayParams(void)
{
  list<param_info>::iterator i;

  // Loop through parameter list
  for (i = g_lstParams.begin(); i != g_lstParams.end(); i++)
  {
    fprintf(OUTPUT, "%s%s%s %s%s%s%s%s %s%s\n",
        i->bConst ? "const " : "",
        i->bOut   ? "/* out */ " : "",
        i->sType.c_str(),
        i->bVar   ? "&" : "",
        i->bArray ? "*" : "",
        i->sName.c_str(),
        i->sDefault != "" ? " = " : "",
        i->sDefault.c_str(),
        distance (i, g_lstParams.end()) == 1 ? "" : ",",
        i->sComment.c_str()
        );
  }

  RemoveParams();
}

// ---------------------------------------------------------------------------
// Display Variables
// ---------------------------------------------------------------------------
void DisplayVariables(void)
{
  list<param_info>::iterator i;

  // Loop through parameter list
  for (i = g_lstParams.begin(); i != g_lstParams.end(); i++)
  {
    string comm;

/*
    if(!g_lstComments.empty())
    {
      comm = g_lstComments.front();
    }
	*/

    if (g_bConvertBody)
    {
      Convert_Type(i->sType);
    }

/*
    fprintf(OUTPUT, "%s %s %s;%s\n",
        g_bConstSec ? "const" : "",
        i->sType.c_str(),
        i->sName.c_str(),
        comm.c_str()
        );
		*/

	OutputLog2("// val = ", i->sDefault.c_str());
    if (i->sDefault != "")
	{
	  
      fprintf(OUTPUT, "%s %s %s = %s; ",
        g_bConstSec ? "const" : "",
        i->sType.c_str(),
        i->sName.c_str(),
		i->sDefault.c_str()
        );

	}
	else
	{
      fprintf(OUTPUT, "%s %s %s; ",
          g_bConstSec ? "const" : "",
          i->sType.c_str(),
          i->sName.c_str()
          );
	}

  	while (!g_lstComments.empty())
	{
	  comm = g_lstComments.front();

	  if (comm == "*/")
	  {
	    fprintf(OUTPUT, "%s\n", comm.c_str());
		g_lstComments.pop_front();
	    break;
	  }

	  fprintf(OUTPUT, "%s", comm.c_str());

	  g_lstComments.pop_front();
	}

	fprintf(OUTPUT, "\n");
  }

  RemoveParams();
}

// ---------------------------------------------------------------------------
// Change between Delphi and C++ strings
// ---------------------------------------------------------------------------
void ChangeStrings(void)
{
    for (int i = 0; i < yyleng; ++i) {
        if (yytext[i] == '\'') {
            // check for double ''
            if (yytext[i+1] == '\'') {
                yytext[i] = '\\';
                ++i;  // safe because of trailing '\0'
            }   else {
                yytext[i] = '\"';
            }
        }   else {
            if (yytext[i] == '\"')
            yytext[i] = '\'';
        }
    }
}

// ---------------------------------------------------------------------------
%}

%{
// ---------------------------------------------------------------------------
// Translate incoming text from Shift-JIS (CP932) to UTF-8.
// ---------------------------------------------------------------------------
#define YY_INPUT(buf,result,max_size) \
	 { \
	int c = getc(yyin); \
	if(0x81 <= c && c <= 0x9f || 0xE0 <= c && c <= 0xff){\
		char cs[3];\
		cs[0] = c;\
		cs[1] = getc(yyin);\
		cs[2] = '\0';\
		wchar_t wcs[3] = L"";\
		MultiByteToWideChar(932, MB_PRECOMPOSED, cs, 2, wcs, sizeof wcs);\
		result = WideCharToMultiByte(CP_UTF8, 0, wcs, 1, buf, max_size, NULL, NULL);\
	}\
	else\
	 result = (c == EOF) ? YY_NULL : (buf[0] = c, 1); \
	 }
%}

ID      [a-z_A-Z][a-z_A-Z0-9]*
NUM     [0-9]*
S       [ \t\n\r]
KEYWORD ("abstract"|"cdecl"|"register"|"dynamic"|"virtual"|"export"|"external"|"far"|"forward"|"override"|"overload"|"pascal"|"reintroduce"|"safecall"|"stdcall")
OPER    ("."|"not"|"@"|"^"|"/"|"div"|"mod"|"shl"|"shr"|"="|"<>"|"and"|"xor"|"or"|":=")
NON_ID  [^a-z_A-Z0-9]

%x PROGRAM UNIT LIBRARY
%x PROGRAM_BEGIN
%x function
%x func_params
%x DefaultVal
%x param_type
%x func_ret
%x comments
%x ccomments
%x mytype
%x myparent
%x myparent2
%x myparent3
%x callback
%x InPlaceCallback
%x InPlaceCallback2
%x InPlaceCallback3
%x directive
%x directive_define
%x directive_ifdef
%x directive_ifndef

%x Body
%x Func_Body
%x InClass
%x ClassVar
%x ClassPtrVar
%x vars
%x Uses
%x Struct
%x Property
%x prop_type
%x Constants
%x   ConstAssign1
%x   ConstAssign2
%x   ConstAssign3
%x Constant2
%x Constant3
%x Enum
%x Array
%x Initialisation
%x ProcessVariable
%x   ProcessVariableType
%x   ProcessVariableType2
%x   ProcessVariableType3
%x ProcessArray
%x   ProcessArraySize
%x   ProcessArrayType
%x ProcessSet
%x   ProcessSetType1
%x   ProcessSetType2
%x ProcessEnum
%x   ProcessEnum1

%x IfThen
%x ForLoop

%%

<*>\n            { ++yylineno; }
<*>\r\n          { ++yylineno; }

<*>^("program") {
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_UNIT) {
        std  ::string err("in unit mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }   else
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_LIBRARY) {
        std  ::string err("in library mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }
    
    cout << "program start" << endl;
    
    g_bTranspilerMode = g_bTranspilerModeType::tm_PROGRAM;
    if (g_bDebugMode) {
        PLOGD << "we've got a program";
    }
    
    BEGIN ( PROGRAM );
}

<*>^("unit") {
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_PROGRAM) {
        std  ::string err("in program mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }   else
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_LIBRARY) {
        std  ::string err("in library mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }
    cout << "unit start" << endl;
    
    g_bTranspilerMode = g_bTranspilerModeType::tm_UNIT;
    if (g_bDebugMode) {
        PLOGD << "we've got a unit";
    }
    
    BEGIN ( UNIT );
}

<*>^("library") {
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_PROGRAM) {
        std  ::string err("in program mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }   else
    if (g_bTranspilerMode == g_bTranspilerModeType::tm_UNIT) {
        std  ::string err("in unit mode.");
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        if (g_bDebugMode) {
            PLOGE << err;
        }
        throw_TranspilerMode( err, loc);
    }
    
    cout << "library start" << endl;
    
    g_bTranspilerMode = g_bTranspilerModeType::tm_LIBRARY;
    if (g_bDebugMode) {
        PLOGD << "we've got a library";
    }
    
    BEGIN (LIBRARY);
}

<*>"{$" {
    if (g_bDebugMode) {
        PLOGD << "got a compiler directive";
    }

    if (YY_START != directive)
    g_nDirectiveCaller = YY_START;

    BEGIN(directive);
}

<*>{KEYWORD} {
    if (g_bDebugMode) {
        PLOGD << "got keyword: " << yytext;
    }

    if (g_bComments || YY_START == function) {
        fprintf(OUTPUT, "%s", yytext);
    }
}

<directive>"}" {
    if (g_bDebugMode) {
        PLOGD << "Finished Directive";
    }

    BEGIN (g_nDirectiveCaller);
    g_nDirectiveCaller = 0;
}

<directive>"define" {
    if (g_bDebugMode) {
        PLOGD << "got a define";
    }
    BEGIN (directive_define);
}

<directive>"else" {
  OutputLog("// Got Else");
  fprintf(OUTPUT, "#else\n");
  BEGIN(directive);
}

<directive>"endif" {
  OutputLog("// Got EndIf");
  fprintf(OUTPUT, "#endif\n");
  BEGIN(directive);
}

<directive>"IfDef" {
  OutputLog("// Got IfDef");
  fprintf(OUTPUT, "#ifdef ");
  BEGIN(directive_ifdef);
}

<directive>"IfNDef" {
  OutputLog("// Got IfNDef");
  fprintf(OUTPUT, "#ifndef ");
  BEGIN(directive_ifndef);
}

<directive>[^}] {
}

<directive_define>{ID} {
  fprintf(OUTPUT, "#define %s\n", yytext);
  BEGIN(directive);
}

<directive_ifdef>{ID} {
  fprintf(OUTPUT, "%s\n", yytext);
  BEGIN(directive);
}

<directive_ifndef>{ID} {
  fprintf(OUTPUT, "%s\n", yytext);
  BEGIN(directive);
}

<PROGRAM>{S}*{ID}{S}*; {
        std::string id;
    
    {   const auto target      = std::regex { " " };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ yytext };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };

    {   const auto target      = std::regex { ";" };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ id  };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };
    
    if (g_bDebugMode) {
        PLOGD << "program name: " << id;
    }
	
	BEGIN ( Body );
}
<PROGRAM>. {
    std  ::string err( SE_syntax_expect_semi.data() );
    boost::source_location const & loc = BOOST_CURRENT_LOCATION;
    if (g_bDebugMode) {
        PLOGE << err;
    }
    throw_SyntaxError( err, loc );
}

<UNIT>{S}*{ID}{S}*; {
        std::string id;
    
    {   const auto target      = std::regex { " " };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ yytext };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };

    {   const auto target      = std::regex { ";" };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ id  };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };
    
    if (g_bDebugMode) {
        PLOGD << "unit name: " << id;
    }

	BEGIN ( Body );
}
<UNIT>. {
    std  ::string err("expected ;");
    boost::source_location const & loc = BOOST_CURRENT_LOCATION;
    if (g_bDebugMode) {
        PLOGE << err;
    }
    throw_SyntaxError( err, loc );
}

<LIBRARY>{S}*{ID}{S}*; {
        std::string id;
    
    {   const auto target      = std::regex { " " };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ yytext };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };

    {   const auto target      = std::regex { ";" };
        const auto replacement = std::string{ ""  };
        const auto value       = std::string{ id  };
        
        id = regex_replace(
        value,
        target,
        replacement);
    };

    if (g_bDebugMode) {
        PLOGD << "library name: " << id;
    }

	BEGIN ( Body );
}
<LIBRARY>. {
    std  ::string err("expected ;");
    boost::source_location const & loc = BOOST_CURRENT_LOCATION;
    if (g_bDebugMode) {
        PLOGE << err;
    }
    throw_SyntaxError( err, loc );
}

<PROGRAM_BEGIN>{S}*; {

    BEGIN ( Body );
}

<comments>[^}\n]* {
  OutputLog("// End processing block comments");
  ProcessComment();
}

<*>"//"[^\n]*\n {
  OutputLog("// End processing line comments");
  ProcessComment();
}

<Body>{S}{ID}{S}":=" {
  fprintf(OUTPUT, "%s", yytext);
}

<Body>interface {
  OutputLog("// got interface");
}

<Body>"uses" {
    if (g_bDebugMode) {
        PLOGD << "processing a uses section";
    }
    g_cUsesStart = true;
    
    g_bType = false;
    BEGIN ( Uses );
}

<InClass,Struct,Constants,Body,Func_Body>{S}+end{S}+[^;]*";" {
  OutputLog("// Processing end with comments");
  string str = yytext;

  int i = str.find("end", 0);
  int s = str.find(";");
  if (i != string::npos)
    str.replace(i, 4, "end;" );

  if (s != string::npos)
    str.replace(s, 1, " ");

  
}

<InClass,Struct,Constants,Body>(^end;|{S}end;|{S}end{S};) {
  OutputLog("// Got end in InClass,Struct or Constants");
  OutputLog2("//", yytext);

  if (!g_bComments)
  {
    OutputLog("// Not a comment");
    if (g_bFuncBody)
    {
      OutputLog("// In function body");
      if (g_nBegins > 0)
        g_nBegins--;

      ProcessEnd();
      g_bStructure = false;

      if (g_nBegins > 0)
        BEGIN(Func_Body);
      else
        BEGIN(mytype);
    }
    else
    {
      OutputLog("// investigate this... we haven't decremented counter");
      ProcessEnd();
      g_bStructure = false;
      BEGIN(mytype);
    }
  }
}

<Body,Constants>^{S}*type {
  if (g_bImplementation)
  {
    OutputLog("// Ignore type Section");

    fprintf(OUTPUT, "#ifdef INCLUDE_TYPE_SECTION\n");
    g_bIgnoreTypeSection = true;

    g_bType = true;
    g_bConstSec = false;
    BEGIN(mytype);
/*
// removed this to investigate other ways of handling type section
    g_bVars = true;
    fprintf(OUTPUT, "\n/*\r\n//type\n");
    g_bComments = true;
    g_bIgnore = true;
    BEGIN(vars);
*/
  }
  else
  {
    OutputLog("// Not Ignoring type Section");

    g_bType = true;
    g_bConstSec = false;
    BEGIN(mytype);
  }
}

<Body,Constants>^(const|resourcestring) {
	OutputLogHead();
  if (g_bIgnoreImplementation && g_bImplementation)
  {
    OutputLog("// Ignore const Section");
    fprintf(OUTPUT, "/*\n//const\n");
    g_bVars = true;
    g_bComments = true;
    g_bIgnore = true;
    BEGIN(vars);
  }
  else
  {
    OutputLog("// Not Ignoring const Section");

    g_bType = false;
    g_bClassBody = false;
    g_bConstSec = true;
    BEGIN(Constants);
  }
}

<Body>^var|{S}*var {
  if (g_bImplementation)
  {
    OutputLog("// Ignore var Section");

    g_bVars = true;
    fprintf(OUTPUT, "/*\nvar\n");
    g_bComments = true;
    BEGIN(vars);
  }
  else
  {
    OutputLog("// in a type varsection");

    g_bType = false;
    g_bClassBody = false;
    g_bConstSec = false/*true*/;
    BEGIN(Constants);
  }
}

<vars>{NON_ID}+begin|asm{NON_ID}+        {
	OutputLogHead();
  OutputLogNum("// Got Begin (vars) - ", g_nBegins);

  if (g_bIgnore)
  {
    OutputLog("// Stop ignoring");
    g_bIgnore = false;
  }

  g_nBegins++;
  g_bVars = false;
  fprintf(OUTPUT, "*/\n{");

  if (!g_bKeepBody)
  {
    fprintf(OUTPUT, "\n#ifndef DOXYGEN_SKIP\n");
  }

  g_bComments = false;
  g_bFuncBody = true;
  BEGIN(Func_Body);
}

<vars>{NON_ID}+implementation{NON_ID}+ {
	OutputLogHead();

  if (g_bInterfaceOnly)
  {
    OutputLog("// End of \'Interface\' section - finish now");
    yyterminate();
  }

  fprintf(OUTPUT, "*/\n");
  OutputLog("// Processing an implementation section (vars)");

  g_bType = false;
  g_bImplementation = true;
  g_bConstSec = false;
  BEGIN(Body);

  // Tidy up if we're ending a class
  if (pClass)
  {
    delete pClass;
    pClass = NULL;
    g_bClassBody = false;
  }
}

<vars>{NON_ID}(function|procedure|begin){NON_ID}+ {
	OutputLogHead();
  if (g_bIgnore)
  {
    OutputLog("// section ignore");
    fprintf(OUTPUT, "*/\n");
  }

  g_bIgnore = false;
  g_bComments = false;

  // yytext has at least a NON_ID and following (function|procedure|begin), so
  // we're safe to advance pointer here.
  //PushText(yytext + 1);

  g_bType = false;
  g_bConstSec = false;
  g_bImplementation = true;
  g_nBegins = 0;

  ProcessFunction(NORMAL);
  BEGIN(function);
}

<Constants>{NON_ID}+{ID}+{S}*:{S}*(function|procedure) {
	OutputLogHead();
  OutputLog2("// detected in-place function pointer", yytext);
  if (g_bIgnore)
  {
    OutputLog("// section ignore");
    fprintf(OUTPUT, "*/\n");
  }

  g_bIgnore = false;
  g_bComments = false;
  //PushText(yytext);

  g_bType = false;
  g_bConstSec = false;
  g_nBegins = 0;

  g_bCallback = true;
  ProcessFunction(NORMAL, true);
  BEGIN(InPlaceCallback);
}

<InPlaceCallback>{ID} {
//	OutputLogHead();
//  OutputLog2("// in-place function pointer name", yytext);
//  pFunc->sName = yytext;
//  fprintf(OUTPUT, "typedef %s (*%s)(", pFunc->sRet != "" ? pFunc->sRet.c_str() : "void",
//    pClass->sName.c_str());
	BEGIN(InPlaceCallback2);
}

<InPlaceCallback2>: {
	OutputLogHead();
	OutputLog("// in-place function pointer eats up :");
	BEGIN(InPlaceCallback3);
}

<InPlaceCallback3>(function|procedure) {
	//OutputLogHead();
	//{S}*\(.*\){S}*:{S}*{ID};
	//OutputLog2("// in-place function pointer type declaration begins, callback = ", g_bCallback ? "true" : "false");
	BEGIN(callback);
}


<vars>"{*}" {
}

<Func_Body>{S}*"inherited"{S}+ {

  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "\n::");
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen>"<>" {
  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "!=");
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen,Body>")"{S}*{OPER}{S}*"(" {
  string op = yytext;
  Convert_Op(op, true);

  fprintf(OUTPUT, "%s", op.c_str());
}


<Func_Body,IfThen,Body>{OPER} {
  string op = yytext;
  Convert_Op(op, false);

  fprintf(OUTPUT, "%s", op.c_str());
}

<Func_Body>^if|{S}+if{S}+ {
  if (g_bConvertBody)
  {
    OutputLog("// Processing if ");
    //PushText(yytext);
    BEGIN(IfThen);
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body>"for ".*"do" {
  if (g_bConvertBody)
  {
    OutputLog("// Processing for  ");
    //PushText(yytext);
    BEGIN(ForLoop);
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<ForLoop>"for ".*"do" {

  if (g_bConvertBody)
  {
    string str = yytext;
    string lowstr = str;

//    std::transform (lowstr.begin(),lowstr.end(), lowstr.begin(), tolower); // #@@
	for(int i = 0; i < lowstr.size(); i++)
		lowstr[i] = tolower(lowstr[i]); 

    int forpos = lowstr.find("for", 0);
    int dopos = lowstr.find("do", 0);

    int eqpos;

    eqpos = str.find(":=", 0);
    if (eqpos != string::npos)
    {
      str.replace(eqpos, 2, " =");
    }
    else
    {
      eqpos = str.find('=', 0);
      if (eqpos != string::npos)
      {
        str.replace(eqpos, 2, "==");
      }
    }

    int topos = lowstr.find("to", 0);

    string init = str.substr(forpos + 3, eqpos - (forpos+3));
    string initval = str.substr(eqpos+1, topos - (eqpos+1));
    string opstr = str.substr(topos+2, dopos - (topos+2));

    fprintf(OUTPUT, "for (%s%s; %s < %s;)", init.c_str(), initval.c_str(), init.c_str(),
      opstr.c_str());

  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }

  BEGIN(Func_Body);
}

<Func_Body,IfThen>"self" {
  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "this");
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen>"self." {
  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "this->");
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen>{ID}"."{ID}|{ID}"("{ID}")""."{ID} {
  if (g_bConvertBody)
  {
    string str = yytext;
    int i = str.find('.', 0);
    str.replace(i, 1, "->" );

    i = str.find("self->", 0);
    if (i != string::npos)
      str.replace(i, 4, "this" );

    fprintf(OUTPUT, "%s", str.c_str());
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen>{ID}";" {
  if (g_bConvertBody)
  {
    string str = yytext;
    // todo : should think about keeping a list of variables and either
    // adding () for function calling, or leave alone for variables.
//    int i =  str.find(';', 0);
//    str.replace(i, 3, "();" );
    fprintf(OUTPUT, "%s", str.c_str());
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body,IfThen>"Owner." {
  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "::");
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Func_Body>{ID}{S}*":"{S}+ {
  if (g_bConvertBody)
  {
    fprintf(OUTPUT, "case %s ", yytext);
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<IfThen>if {
  fprintf(OUTPUT, "if (");
}

<IfThen>"then" {
  fprintf(OUTPUT, ") ");
  BEGIN(Func_Body);
}

<Func_Body>"'"[^']+"'"|"''" {
  fprintf(OUTPUT, "%s",yytext);
}

<Func_Body>{S}case{S}[^*\n]+ {
  OutputLogNum("// Got Case - ", g_nBegins);

  if (!g_bComments)
  {
    g_nBegins++;
    g_bCase = true;
  }

  if (g_bConvertBody)
  {
    string str = yytext;
    int i =  str.find("case ", 0);
    str.erase(i, 5);
    i =  str.find(" of", 0);
    str.erase(i,3);

    string str2 = str;
//    std::transform (str.begin(),str.end(), str2.begin(), tolower); // #@@
	for(int i = 0; i < str2.size(); i++)
		str2[i] = tolower(str2[i]); 

    i = str2.find("self", 0);
    if (i != string::npos)
    {
      str = str.replace(i, 4, "this" );
    }

    i =  str2.find(".", 0);
    if (i != string::npos)
    {
      str = str.replace(i, 1, "->" );
    }

    fprintf(OUTPUT, "switch (%s) {", str.c_str());
  }
  else
  {
    if (!g_bComments)
    {
      fprintf(OUTPUT, "%s\n",yytext);
    }
  }
}

<Func_Body>(^try|{S}try){S} {
  OutputLogNum("// Got Try - ", g_nBegins);

  if (!g_bComments)
  {
    OutputLog("// Not a comment");
    g_nBegins++;
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Body,Func_Body>(^begin|{S}*begin|^asm|{S}asm){S} {
  OutputLogNum("// Got Begin (b/fb) - ", g_nBegins);

  if (!g_bComments)
  {
    OutputLog("// Not a comment");
    g_nBegins++;
    if (g_nBegins > 1)
    {
      if (g_bConvertBody)
      {
        fprintf(OUTPUT, "{");
      }
      else
      {
        fprintf(OUTPUT, "begin");
      }
    }
    else
    {
      fprintf(OUTPUT, "{");

      if (!g_bKeepBody)
      {
        fprintf(OUTPUT, "\n#ifndef DOXYGEN_SKIP\n");
      }
    }
  }

  g_bFuncBody = true;
  BEGIN(Func_Body);
}

<Body>"end." {
  fprintf(OUTPUT, "// finished\n");
  for(; 0 < g_nNamespaces; g_nNamespaces--)
	  fprintf(OUTPUT, "}\n");

  if(g_bIgnoreTypeSection)
  {
    fprintf(OUTPUT, "#endif\n");
  }
}

<Func_Body>(end$|{S}end$|end\x0d)      {
  OutputLogNum("// Got End - ", g_nBegins);

  if (!g_bComments)
  {
    OutputLog("// Not a comment");
    g_nBegins--;
    if (g_nBegins > 0)
    {
      if (g_bConvertBody)
      {
        fprintf(OUTPUT, "}");
      }
      else
      {
        fprintf(OUTPUT, "end");
      }
    }
    else
    {
      fprintf(OUTPUT, "}");

      if (!g_bKeepBody)
      {
        fprintf(OUTPUT, "\n*/\n");
        fprintf(OUTPUT, "\n#endif /* DOXYGEN_SKIP */");
      }
    }
  }

  // was just Body
  BEGIN(Func_Body);
}

<Func_Body>(^end;|{S}end;|{S}end{S};|{S}end{S}|end\x3b|end;\x0a) {
  OutputLogNum("// Got End1 - ", g_nBegins);

  if (!g_bComments)
  {
    OutputLog("// Not a comment");
    g_nBegins--;
    if (g_nBegins == 0)
    {
      if (!g_bKeepBody)
      {
        fprintf(OUTPUT, "\n#endif /* DOXYGEN_SKIP */");
      }

      fprintf(OUTPUT, "\n};");
      g_bFuncBody = false;
      BEGIN(Body);
    }
    else
    {
      if (g_bConvertBody)
      {
        fprintf(OUTPUT, "}");
      }
      else
      {
        fprintf(OUTPUT, "end");
      }

      BEGIN(Func_Body);
    }
  }
}

<Body>^finalization {
  fprintf(OUTPUT, "// %s\n", yytext);
}

<Body>^initialization {
  fprintf(OUTPUT, "// %s\n", yytext);
  fprintf(OUTPUT, "\n#ifndef DOXYGEN_SKIP\n");
  BEGIN(Initialisation);
}

<Initialisation>"end." {
  fprintf(OUTPUT, "// finished\n");
  fprintf(OUTPUT, "#endif\n");
  BEGIN(Body);
}

<*>^implementation {

  if (g_bInterfaceOnly)
  {
    OutputLog("// End of \'Interface\' section - finish now");
    yyterminate();
  }

  OutputLog("// Processing an implementation section");

  g_bType = false;
  g_bConstSec = false;
  g_bImplementation = true;
  g_nBegins = 0;
  BEGIN(Body);

  // Tidy up if we're ending a class
  if (pClass)
  {
    delete pClass;
    pClass = NULL;
    g_bClassBody = false;
  }
}

<Constants>^var {
	OutputLogHead();
  OutputLog("// in a type varsection");

  g_bType = false;
  g_bClassBody = false;
  g_bConstSec = false;
  BEGIN(Constants);
}

<Constants,mytype,Func_Body,InClass,Struct,myparent>{ID}{S}*":"{S}*"("([^)]*)")"{S}*";" {
	OutputLogHead();
  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessEnum);
}

<ProcessEnum>{ID} {
  g_strTypedefName = yytext;
  BEGIN(ProcessEnum1);
} 

<ProcessEnum1>":" {} // eat

<ProcessEnum1>{S}*"("([^)]*)")"{S}* {

  ChangeStrings();

  string str = yytext;
  int pos = str.find("(", 0);
  str = str.replace(pos, 1, "{");
  pos = str.find(")", 0);
  str = str.replace(pos, 1, "}");

  g_strTypedefType = str;
}

<ProcessEnum1>";" {
  fprintf(OUTPUT, "enum %s %s;\n", g_strTypedefName.c_str(), g_strTypedefType.c_str());
  BEGIN(g_nGeneralCaller);
}

<Constants,mytype,Func_Body,InClass,Struct,myparent>{ID}{S}*(":"|"="){S}*"array"{S}*"["([^\]])*"]"{S}*"of"{S}*{ID}{S}*("="{S}*"("([^)]*)")"{S}*)*";" {
	OutputLogHead();
  OutputLog2("// Processing array = ", yytext);

  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessArray);
}

<Constants,mytype,Func_Body,InClass,Struct,myparent>{ID}{S}*("="|":"){S}*("array"|"set"){S}*"of"{S}*{ID}{S}*";" {
	OutputLogHead();
  OutputLog2("// Processing array = ", yytext);

  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessSet);
}

<Constants,mytype,Func_Body,InClass,Struct,myparent>{ID}{S}*("="|":"){S}*"array"{S}*"of"{S}* {
	OutputLogHead();
  OutputLog2("// Processing array of arbitrary type = ", yytext);

  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessSet);
}

<ProcessSet>{ID} {
  g_strTypedefName = yytext;
  BEGIN(ProcessSetType1);
}

<ProcessSetType1>("="|":") {}

<ProcessSetType1,ProcessSetType2>"set"{S}*"of" {
  g_strTypedef = "set";
  g_lArrayStack.push_back(g_strTypedef);
  BEGIN(ProcessSetType2);
}

<ProcessSetType1,ProcessSetType2>"array"{S}*"of" {
  g_strTypedef = "array";
  g_lArrayStack.push_back(g_strTypedef);
  BEGIN(ProcessSetType2);
}

<ProcessSetType2>"("|")"

<ProcessSetType2>{ID} {
  g_strTypedefType = yytext;
}

<ProcessSetType2>"(".*")" {
  static int invokes = 0;
  char buf[256];
  sprintf(buf, "__inplace_enum_%d", invokes);
  g_strTypedefType = buf;
  fprintf(OUTPUT, "/// Automatically generated in-place enumeration typedef by pas2dox\n");
  fprintf(OUTPUT, "enum __inplace_enum_%d{%.*s};\n", invokes, strlen(yytext)-2, yytext+1);
  invokes++;
}

<ProcessSetType2>";" {
  if (g_bConvertBody)
  {
    Convert_Type(g_strTypedefType);
  }

  // if array stack is present, unwrap it recursively
  if(!g_lArrayStack.empty())
  {
    fprintf(OUTPUT, "typedef ");

    // Initialize the result with the "innermost" type
    string result = g_strTypedefType;

    // Enumerate the array stack from the back, to construct C++ template type string
    for(list<string>::reverse_iterator it = g_lArrayStack.rbegin(); it != g_lArrayStack.rend(); it++)
    {
      result = *it + "<" + result + "> ";
    }

    fprintf(OUTPUT, "%s %s;", result.c_str(), g_strTypedefName.c_str());
    g_lArrayStack.clear();
  }
  else
    fprintf(OUTPUT, "typedef %s<%s> %s;", g_strTypedef.c_str(), g_strTypedefType.c_str(),g_strTypedefName.c_str());
  BEGIN(g_nGeneralCaller);
}

<ProcessArray>{ID} {
  pArray = new array_info(yytext, "", 0, "");
  BEGIN(ProcessArraySize);
}

<ProcessArraySize>(":"|"="){S}*"array"{S}*"[" {} // eat up
<ProcessArraySize>"]" {} // eat up

<ProcessArraySize>"byte" {
  OutputLog("// got byte, so size = 255");
  g_nSize = 255;

  g_lstSize.push_back(g_nSize);
}

<ProcessArraySize>"-"*{NUM} {
  g_nSize = atoi(yytext);

  OutputLogNum("// got size = ", g_nSize);
  g_lstSize.push_back(g_nSize);
}

<ProcessArraySize>{ID} {
  OutputLog2("// Need to decide what to do here...", yytext);
  g_nSize = 999;
  g_lstSize.push_back(g_nSize);
}

<ProcessArraySize>"," {
   OutputLog("// got a multidimensional array");
}

<ProcessArraySize>".." {
  /*g_lstSize.pop_back();*/
}

<ProcessArraySize>"]"{S}*"of" { BEGIN(ProcessArrayType); }

<ProcessArrayType>{ID} {
  OutputLog2("// of type", yytext);

  pArray->sType = yytext;

  if (g_bConvertBody)
  {
    Convert_Type(pArray->sType);
  }
}

<ProcessArrayType>"="{S}*"("([^)]*)")"{S}* {

  ChangeStrings();

  string str = yytext;
  int pos = str.find("(", 0);
  str = str.replace(pos, 1, "{");
  pos = str.find(")", 0);
  str = str.replace(pos, 1, "}");

  pArray->sDefault = str;
}

<ProcessArrayType>";" {

  OutputLog("// Processing array type");
  fprintf(OUTPUT, "%s %s", pArray->sType.c_str(), pArray->sName.c_str());

  list<int>::iterator i;

  string comm;
  char buf[12];
  comm = "/*!< [";
  int c = g_lstSize.size();
  int pos = 0;
  for (i = g_lstSize.begin(); i != g_lstSize.end(); ++i, pos++)
  {
  #ifdef _WIN32
    comm += itoa(*i, buf, 10);
  #else
     snprintf(buf, sizeof(buf), "%d", *i);
     comm += buf;
  #endif

	if (pos+1 < c)
	{
	  comm += "..";
	}
	else
	{
	  comm += "] */";
	}
  }

  if (c > 0)
  {
	fprintf(OUTPUT, "[%d]", g_lstSize.back());
  }

  g_lstSize.clear();

  fprintf(OUTPUT, "%s; %s\n", pArray->sDefault.c_str(), comm.c_str());

  if (pArray)
  {
    delete pArray;
    pArray = NULL;
  }

  BEGIN(g_nGeneralCaller);
}

<Constants>{ID}{S}*(","{S}*{ID}{S}*)+":"{S}*{ID}{S}*";" {
	OutputLogHead();
  OutputLog("// got a multiple definition");

  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<Constants>{ID}{S}*":"{S}*{ID}{S}*";" {
	OutputLogHead();
  OutputLog("// Constants");
  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<Constants>{ID}{S}*":"{S}*{ID}{S}*"="{S}*{NUM}";" {
	OutputLogHead();
  OutputLog2("// here 1723 ", yytext);
  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<Constants>{ID}{S}*"="{S}*('[^'\n]*'|[^;{\n]*)";" {
	OutputLogHead();
  OutputLog2("// x = [']y['] = ", yytext);
  //PushText(yytext);
  BEGIN(ConstAssign1);
}

<ConstAssign1>{ID} {
	OutputLogHead();
  OutputLog2("// got ID = ", yytext);

  if (pClass)
    delete pClass;

  pClass = new class_info;
  pClass->sName = yytext;
  BEGIN(ConstAssign2);
}

<ConstAssign2>"=" {
  OutputLog("// got equals");
  BEGIN(ConstAssign3);
}

<ConstAssign3>('[^'\n]*'|[^;{\n]*)";" {
  OutputLog("// ConstAssign - output");

  ChangeStrings();

  fprintf(OUTPUT, "const %s %s = %s", pClass->sType.c_str(), pClass->sName.c_str(), yytext);

  if (pClass)
  {
    delete pClass;
    pClass = NULL;
  }

  BEGIN(Constants);
}

<mytype>^const|resourcestring {
  OutputLog("// in a type const section");

  g_bType = false;
  g_bClassBody = false;
  g_bConstSec = true;
  BEGIN(Constants);
}

<mytype>^var {
  OutputLog("// in a type varsection");

  g_bType = false;
  g_bClassBody = false;
  g_bConstSec = false/*true*/;
  BEGIN(Constants);
}

<mytype>{ID}{S}"="{S}"-"*{ID}"("{ID}")"".."{ID}"("{ID}")"";" {
  // TODO : Enum - Similar to arraydef
  fprintf(OUTPUT, "// %s\n", yytext);
}

<mytype>{ID}{S}"="{S}"-"*{ID}*".."{ID}";" {
  // TODO : Enum - Similar to arraydef
  fprintf(OUTPUT, "// %s\n", yytext); }

<mytype,Constants>function|procedure|constructor|destructor          {
  OutputLog2("// type processing :", yytext);

  func_type ft = NORMAL;
  if (strcmp(yytext, "destructor") == 0)
    ft = DESTRUCTOR;

  if (strcmp(yytext, "constructor") == 0)
    ft = CONSTRUCTOR;

  ProcessFunction(ft);
  BEGIN(function);
}

<myparent>"="{S}*("procedure"|"function") {

  OutputLog("// function typedef processing");
  g_bCallback = true;
  ProcessFunction(NORMAL);
  BEGIN(callback);
}

<callback>"(" {
  OutputLog("// We've got a parameter list for this function");
  g_bParams = true;
  BEGIN(func_params);
}

<callback>":" {
  BEGIN(func_ret);
}

<callback>";"|"of object;" {
  OutputLog("// function typedef details");
  g_bCallback = false;

/*
  fprintf(OUTPUT, "typedef %s (*%s)(", pFunc->sRet != "" ? pFunc->sRet.c_str() : "void",
    pClass->sName.c_str());
*/
  if(pFunc->sName == "")
    pFunc->sName = pClass->sName;
  pFunc->pascalize();

  DisplayParams();

  fprintf(OUTPUT, ");\n");

  if (pFunc)
  {
    delete pFunc;
    pFunc = NULL;
  }

  if (pClass)
  {
    delete pClass;
    pClass = NULL;
  }

  BEGIN(mytype);
}

<myparent>"="{S}*"record" {
	// record識別子の前のスペース数を可変にした
  OutputLog("// processing a record structure");

  fprintf(OUTPUT, "struct %s\n{\n", pClass->sName.c_str());
  BEGIN(InClass);
  g_bStructure = true;
}

<myparent>"="{S}*"packed record" {
	// packed record識別子の前のスペース数を可変にした
  OutputLog("// got a packed record");

  fprintf(OUTPUT, "struct %s\n{\n", pClass->sName.c_str());
  BEGIN(InClass);
  g_bStructure = true;
}

<myparent>"="{S}*"(" {
  ProcessEnums();
  BEGIN(Enum);
}

<myparent>"="{S}*"set"{S}+"of"{S}*"(" {
	ProcessEnums();
	BEGIN(Enum);
}

<Enum>({NUM}"."{NUM}|{NUM}) {
  OutputLog2("// enum num: ", yytext);

  param_info p ("", yytext,  "", "", false, false, false, false);
  lstParams.push_back(p);
}

<Enum>"'"{ID}"'" {
  OutputLog2("// enum 'id': ", yytext);

  param_info p ("", yytext,  "", "", false, false, false, false);
  lstParams.push_back(p);
}

<Enum>{ID} {
  OutputLog2("// enum id: ", yytext);

  param_info p ("", yytext,  "", "", false, false, false, false);
  lstParams.push_back(p);
}

<Enum>{ID}{S}*"="{S}*"-"*{NUM} {
  OutputLog2("// enum here 1: ", yytext);

  string id = yytext;

  int pos = id.find('=', 0);
  string ids = id.substr(0,pos);

  //fprintf(OUTPUT, "int %s", ids.c_str());
    param_info p ("", yytext,  "", ids.c_str(), false, false, false, false);
  lstParams.push_back(p);
}

<Enum>","
<Enum>\n
<Enum>{S}
<Enum>")"  {

  DisplayEnum();
  RemoveParams();

  fprintf(OUTPUT, "};\n");

  g_bEnum = false;
  g_bParams = false;
}

<Enum>";" {

  if (g_bClassBody)
  {
    BEGIN(InClass);
  }
  else if (g_bType)
  {
    BEGIN(mytype);
  }
  else
  {
    BEGIN(Body);
  }

  if (g_bParams)
  {
    if (g_bEnum)
    {
      BEGIN(Enum);
    }
    else
    {
      BEGIN(func_params);
    }
  }

}

<mytype>{ID}{S}*"="{S}*"-"*{NUM}".."{NUM} {
  OutputLog2("// here 1: ", yytext);

  string id = yytext;

  int pos = id.find('=', 0);
  string ids = id.substr(0,pos);

  fprintf(OUTPUT, "int %s", ids.c_str());
}

<mytype>type {
  OutputLog("// ignore type keyword");
}

<mytype>(^end;|{S}end;|{S}end{S};) {
  OutputLog("// Ignore end...");
}

<mytype>{ID} {
  OutputLog2("// processing types : ", yytext);
  // Processing a class

  // Just in case...
  if (pClass)
    delete pClass;

  pClass = new class_info;
  pClass->sName = yytext;
  BEGIN(myparent);
}

<myparent>("="|":"){S}*"class of" {
  OutputLog("// pointer to class");
  BEGIN(ClassPtrVar);
}

<myparent>("="|":"){S}*"^" {
  OutputLog("// pointer to class");
  BEGIN(ClassPtrVar);
}

<myparent>"="{S}"interface"{S}*"(" {
  g_bInterface = true;
  BEGIN(myparent2);
}

<myparent>"="{S}*"class"{S}*";" {
  OutputLog("// got x = class;");
  fprintf(OUTPUT, "class %s;\n", pClass->sName.c_str());

  BEGIN(mytype);
}

<myparent>"="{S}*"class"{S}*"(" {
	// class識別子の前のスペース数を可変にした
  BEGIN(myparent2);
} // Processing a class

<myparent2>","  // Ignore comma

<myparent2>{ID} {

  if (pClass->sParent != "")
  {
    OutputLog2("// Assigning parent2 : ", yytext);
    pClass->sParent2 = yytext;
  }
  else
  {
    OutputLog2("// Assigning parent : ", yytext);
	OutputLog2("// Name parent : ", pClass->sName.c_str());
    pClass->sParent = yytext;
  }
}

<myparent2>";" {
  OutputLog("// Output class details");
  fprintf(OUTPUT, "class %s : public %s,%s\n{\n", pClass->sName.c_str(), pClass->sParent.c_str(),
    pClass->sParent2.c_str());

  g_bClassBody = true;
  BEGIN(InClass);
}

<myparent2>")"";" {
  OutputInheritedClass(1);
  BEGIN(mytype);
}

<myparent2>")" {

  OutputInheritedClass(0);
  BEGIN(InClass);
}

<myparent>"="{S}*"class" {
	// class識別子の前のスペース数を可変にした
  OutputLog("// got base class");

  OutputInheritedClass(0);
  BEGIN(InClass);
}

<myparent>"="{S} { BEGIN(myparent3); }
<myparent>"="{S}"type" { BEGIN(myparent3); }
<myparent3>{ID} {

  OutputLog("// output class details and tidy up");

  pClass->sParent = yytext;
  fprintf(OUTPUT, "typedef %s %s", pClass->sParent.c_str(), pClass->sName.c_str());
  BEGIN(mytype);
}

<InClass,Body>published {

  if (g_bClassBody)
  {
    fprintf(OUTPUT, "public:"); BEGIN(InClass);
  }
  else
  {
    fprintf(OUTPUT, "%s", yytext);
  }
}

<InClass,Body>public|private|protected {

  OutputLog("// got keyword");

  if (g_bClassBody)
  {
    fprintf(OUTPUT, "%s:", yytext);
    BEGIN(InClass);
  }
  else
  {
    // some keyword appearing as text
    fprintf(OUTPUT, "%s", yytext);
  }
}

<Body,InClass>(^property|{S}property) {

  // Just in case...
  if (pProperty)
    delete pProperty;

  pProperty = new prop_info;

  pProperty->sName = "";
  pProperty->sType = "";
  BEGIN(Property);
}

<InClass>"["[^\]]+"]" {
  OutputLog("// Processing GUID");
  fprintf(OUTPUT, "%s", yytext);
}

<Property>"["[^\]]+"]" {
  fprintf(OUTPUT, "/*%s*/", yytext);
}


<Property>":" { BEGIN(prop_type); }

<prop_type>read { pProperty->bRead = true; }
<prop_type>write { pProperty->bRead = false; }

<prop_type>default{S}{NUM} {
  OutputLog("// got default");
  pProperty->sDefault = yytext;
 }

<prop_type>default{S}{ID} {
  OutputLog("// got default");
  pProperty->sDefault = yytext;
}
<prop_type>{ID} {
  OutputLog2("// prop type :", yytext);

  if (g_bFom)
  {
    if (pProperty->bRead)
    {
      pProperty->sRead = yytext;
    }
    else
    {
      pProperty->sWrite = yytext;
    }
  }
  else
  {
    pProperty->sType = yytext;

    g_bFom = true;
  }
}

<Property,prop_type>";" {

  if (g_bGenerateSa)
  {
    if (pProperty->sRead != "" && pProperty->sWrite != "")
    {
      fprintf(OUTPUT, "/** \\sa %s For reading   \\sa %s For writing */\n", pProperty->sRead.c_str(), pProperty->sWrite.c_str());
    }
    else if (pProperty->sRead != "")
    {
      fprintf(OUTPUT, "/** \\sa %s For reading*/\n", pProperty->sRead.c_str());
    }
    else if (pProperty->sWrite != "")
    {
      fprintf(OUTPUT, "/** \\sa %s For writing*/\n", pProperty->sWrite.c_str());
    }
  }

  fprintf(OUTPUT, "%s %s; \n", pProperty->sType.c_str(), pProperty->sName.c_str() );

  if (pProperty)
  {
    delete pProperty;
    pProperty = NULL;
  }

  g_bFom = false;

  if (g_bClassBody)
  {
    BEGIN(InClass);
  }
  else
  {
    BEGIN(Body);
  }
}

<Property>{ID}  {
  OutputLog2("// property :", yytext);

  pProperty->sName = yytext;
}

<Body,InClass>default;

<*>"{*}"        // Eat up {*}
<*>"{**" {
  OutputLog("daz2");
  if (!g_bComments)
  {
    if (!g_bIgnore)
    {
      if (g_bJavaDoc)
        fprintf(OUTPUT, "/**");
      else
        fprintf(OUTPUT, "/***");
    }

    g_bComments = true;
  }

  if (YY_START != comments)
    g_nCommentCaller = YY_START;

  BEGIN(comments);
}

<*>"{" {
  OutputLog("// Processing Block Comments");

  if (g_bVars)
  {
    fprintf(OUTPUT, yytext);
  }
  else
  {
    if (!g_bComments)
    {
      if (!g_bIgnore)
      {
        if (!g_bParams)
        {
          fprintf(OUTPUT, "/*");
        }
        else if(!lstParams.empty())
        {
            lstParams.back().sComment += "/*";
        }
      }

      g_bComments = true;
    }
  }

  if (YY_START != comments)
    g_nCommentCaller = YY_START;

  BEGIN(comments);
}

<*>"}" {

  if (g_bVars)
  {
    OutputLog("g_bVars is true");
    fprintf(OUTPUT, yytext);
  }
  else
  {
    if (g_bIgnore)
    {
      OutputLog("// Ignore section in progress");
    }
    else
    {
      if (!g_bParams)
      {
        OutputLog("g_bParams is false");
        fprintf(OUTPUT, "*/ ");
      }
      else if(!lstParams.empty())
      {
        lstParams.back().sComment += "*/";
      }
      g_bComments = false;
    }
  }

  BEGIN(g_nCommentCaller);
  g_nCommentCaller = 0;
}

<*>"(*" {
  // The pattern "*)" doesn't match though I don't know why.
  OutputLog("CurlyCommentInclusive");
  fprintf(OUTPUT, "/*");
//  fprintf(OUTPUT, "%.*s", yyleng - 4, &yytext[2]);
//  fprintf(OUTPUT, "*/");

  if (YY_START != ccomments)
    g_nCommentCaller = YY_START;

  BEGIN(ccomments);
}

<ccomments>"*)" {
  fprintf(OUTPUT, "*/");
  BEGIN(g_nCommentCaller);
  g_nCommentCaller = 0;
}

<Body,InClass,Struct>function|procedure|constructor|destructor          {

  if (g_nBegins > 0)
  {
    fprintf(OUTPUT, "%s", yytext);
  }
  else
  {
    OutputLog2("// processing a ", yytext);

    if (g_bComments)
    {
      // print the keyword, then continue commenting
      fprintf(OUTPUT, "%s", yytext);
      BEGIN(comments);
    }
    else
    {
      func_type ft = NORMAL;
      if (strcmp(yytext, "destructor") == 0)
        ft = DESTRUCTOR;

      if (strcmp(yytext, "constructor") == 0)
        ft = CONSTRUCTOR;

      ProcessFunction(ft);
      BEGIN(function);
    }
  }
}

<function>{ID}"."{ID} {
	OutputLogHead();
  OutputLog2("// processing function class.name :", yytext);
  string s = yytext;

  int pos = s.find('.', 0);
  int len = s.length();

  OutputLogNum("// Found . at position", pos);

  pFunc->sClass = s.substr(0, pos);
  pFunc->sName = s.substr(pos + 1, len -(pos+1) );

  OutputLog2("// Class = ", pFunc->sClass.c_str());
  OutputLog2("// Name  = ", pFunc->sName.c_str());
}

<function>{ID} {
	OutputLogHead();
  OutputLog2("// process function name :", yytext);
  pFunc->sName = yytext;
}

<function>"(" {
	OutputLogHead();
  OutputLog("// We've got a parameter list for this function");
  g_bParams = true;
  BEGIN(func_params);
}

<func_ret>{ID}"."{ID} {

  string str = yytext;

  string strUnit;
  string strRet;

  int pos = str.find('.', 0);
  int len = str.length();

  strUnit = str.substr(0, pos);
  strRet = str.substr(pos + 1, len -(pos+1) );

  fprintf(OUTPUT, "/// \\sa %s\n", strUnit.c_str());
  pFunc->sRet = strRet;

  if (g_bCallback)
  {
    BEGIN(callback);
  }
  else
  {
    BEGIN(function);
  }
}

<func_ret>{ID} {
  OutputLog2("// assign return type :", yytext);

  pFunc->sRet = yytext;

  if (g_bCallback)
  {
    BEGIN(callback);
  }
  else
  {
    BEGIN(function);
  }
}

<func_params>")"":" {
ProcessParameterType(g_processtype.c_str());
  OutputLog("// Parameter list has finished - there's a return type to be got");
  g_bParams = false;

  BEGIN(func_ret);
}


<func_params>")" {
ProcessParameterType(g_processtype.c_str());
  OutputLog("// Parameter list has finished");

  g_bAtEnd = true;
}

<func_params>"var"        { g_bVar = true; }

<func_params>"out" {
  g_bOut = true;

  // display parameter wise, treat in the same way as a var
  g_bVar = true;
}

<func_params>"const"      { g_bConst = true; }
<func_params>"of"

<func_params>"=" {
  OutputLog("// about to assign value");

  BEGIN(DefaultVal);
}

<DefaultVal>"'"[^']+"'" {
  //lstParams.back().sDefault = yytext;
  g_defaultvalue = yytext;
  ProcessParameterType(g_processtype.c_str());
  BEGIN(func_params);
}

<DefaultVal>"[]" {
  g_defaultvalue = yytext;
  ProcessParameterType(g_processtype.c_str());
  BEGIN(func_params);
}

<DefaultVal>"''" {
  //lstParams.back().sDefault = yytext;
  g_defaultvalue = yytext;
  ProcessParameterType(g_processtype.c_str());
  BEGIN(func_params);
}

<DefaultVal>{ID} {
  OutputLog2("// defaultval id : ", yytext);

  //lstParams.back().sDefault = yytext;
  g_defaultvalue = yytext;
  ProcessParameterType(g_processtype.c_str());
  BEGIN(func_params);
}

<DefaultVal>{NUM} {
  //lstParams.back().sDefault = yytext;
  g_defaultvalue = yytext;
  ProcessParameterType(g_processtype.c_str());
  BEGIN(func_params);
}

<func_params>{ID} {
  OutputLog2("// assign parameter info :", yytext);

  g_defaultvalue = "";
  g_processtype = "";

  param_info p("", yytext, "", "", g_bConst, g_bVar, g_bOut, g_bArray);
  lstParams.push_back(p);
}

<function>{S}":"{S}    {
	OutputLogHead();
	BEGIN(func_ret); }	// Get return type
<function>":"    {
	OutputLogHead();
	BEGIN(func_ret); }		// Get return type

<function>";" {
	OutputLogHead();

  list<param_info>::iterator i;

  OutputLog("// output function details");
  OutputLog(g_bClassBody ? "// g_bClassBody = true" : "// g_bClassBody = false");

// ------------------------
  // todo : remove this and fix underlying cause
  // needed to add, so function details are outputted correctly.
  fprintf(OUTPUT, "\n");
// ------------------------

  // Any return type?
  if (pFunc->sRet != "")
  {
    fprintf(OUTPUT, "%s ", pFunc->sRet.c_str() );
  }

  // destructor
  if (pFunc->eFuncType == DESTRUCTOR)
  {
    if (g_bClassBody)
    {
      // If we encounter a inner class (class contained in a class),
      // pClass can be NULL.
      // In that case, just give up further processing and just
      // try not to generate an access violation.
      if(pClass)
      {
        fprintf(OUTPUT, "~");
        if (pClass->sName != "")
        {
          pFunc->sName = pClass->sName;
        }
      }
    }
    else
    {
      if (pFunc->sClass != "")
      {
        pFunc->sName = "~" + pFunc->sClass;
      }
    }
  }

  // constructor
  if (pFunc->eFuncType == CONSTRUCTOR)
  {
    if (g_bClassBody)
    {
      // If we encounter a inner class (class contained in a class),
      // pClass can be NULL.
      // In that case, just give up further processing and just
      // try not to generate an access violation.
      if(pClass)
      {
        if (pClass->sName != "")
        {
          pFunc->sName = pClass->sName;
        }
      }
    }
    else
    {
      if (pFunc->sClass != "")
      {
        pFunc->sName = pFunc->sClass;
      }
    }
  }

  // Class
  if (pFunc->sClass != "" )
  {
    fprintf(OUTPUT, "%s::", pFunc->sClass.c_str() );
  }

  // Function name
  fprintf(OUTPUT, "%s (", pFunc->sName.c_str() );

  DisplayParams();

  fprintf(OUTPUT, ")");

  if (g_bClassBody || !g_bImplementation)
  {
    fprintf(OUTPUT, ";\n");
  }
  else
  {
    fprintf(OUTPUT, "\n");
  }

  if (pFunc)
  {
    delete pFunc;
    pFunc = NULL;
  }

  if (g_bClassBody)
  {
    BEGIN(InClass);
  }
  else
  {
    BEGIN(Body);
  }
}

<func_params>\n { }
<function>\n { }
<func_params>"," { }

<func_params>";"|"of object;" {
  OutputLog("// func_params 1");

  ProcessParameterType(g_processtype.c_str());

  if(g_bAtEnd)
  {
    g_bAtEnd = false;
    g_bParams = false;
    //PushText(yytext);
    pFunc->sRet = "";

    if (g_bCallback)
    {
      BEGIN(callback);
    }
    else
    {
      BEGIN(function);
    }
  }
}

<func_params>":" {

  if (g_bAtEnd)
  {
    OutputLog("// Parameter list has finished - there's a return type to be got");
    g_bParams = false;
    g_bAtEnd = false;

    BEGIN(func_ret);
  }
  else
  {
    g_bConst = false;
    g_bOut = false;
    g_bVar = false;
    g_bArray = false;
    BEGIN(param_type);
  }
}

<param_type>{ID}"."{ID} {

  string str;

  str = yytext;

  int i =  str.find('.', 0);
  str = str.replace(i, 3, "::" );
  OutputLog2("// param type :", str.c_str());

  ProcessParameterType(str.c_str());

  BEGIN(func_params);
}

<param_type>"array of" {
  OutputLog("// Processing array of ");

  list<param_info>::iterator i;
  i = lstParams.begin();
  i->bArray = true;
}

<param_type>{ID} {
  OutputLog2("// processing parameter type :", yytext);

  //ProcessParameterType(yytext);
  g_processtype = yytext;

  BEGIN(func_params);
}

<ClassVar>"="{S}*"(" {
  ProcessEnums();
  BEGIN(Enum);
}

<ProcessVariable>{ID} {
  OutputLog2("// ProcessVariable ", yytext);

  g_bParams = true;

  param_info p ("", yytext,  "", "", false, false, false, false);
  lstParams.push_back(p);

  BEGIN(ProcessVariableType);
}

<ProcessVariableType>"," {
  OutputLog("// we've got a multiple variable definition");

  BEGIN(ProcessVariable);
}

<ProcessVariableType>":" {}	// Eat up the colon

<ProcessVariableType>{ID} {
  OutputLog2("// ProcessVariableType :", yytext);
  g_processtype = yytext;
  BEGIN(ProcessVariableType2);
}

<ProcessVariableType2>";" {
  OutputLog("// output the variable definition2");

  ProcessParameterType(g_processtype.c_str());
  DisplayVariables();
  g_bParams = false;

  BEGIN(g_nGeneralCaller);
}

<ProcessVariableType2>"=" {
  BEGIN(ProcessVariableType3);
}

<ProcessVariableType3>"-"*{NUM} {
  g_defaultvalue = yytext;

  OutputLog2("// got size = ", yytext);
  
  ProcessParameterType(g_processtype.c_str());

  BEGIN(ProcessVariableType);
}

<ProcessVariableType>";" {
  OutputLog("// output the variable definition");

  DisplayVariables();
  g_bParams = false;

  BEGIN(g_nGeneralCaller);
}

<InClass,Struct,mytype>{ID}{S}*(","{S}*"//"[^}\n]*)+ {
  OutputLog("// multiple def with comments");
  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<InClass,Struct,Constants,mytype>{ID}{S}*":"{S}*"-"*{NUM}{S}*".."{S}*"-"*{NUM}{S}*";" {
  OutputLog2("// got a subrange var = ", yytext);

  string str = yytext;
  int pos = str.find(':', 0);
  int len = str.length();

  string name = str.substr(0,pos);
  string rest = str.substr(pos + 1, len -(pos+1) );

  fprintf(OUTPUT, "long %s;  ", name.c_str());
  fprintf(OUTPUT, "/**< Subrange %s */\n", rest.c_str());
}

<InClass,Struct,mytype>{ID}{S}*(","{S}*{ID}{S}*)+":"{S}*{ID}{S}*";" {
  OutputLog("// got a multiple definition");

  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<InClass,Struct>{ID}{S}*":"{S}*{ID}{S}*";" {
  OutputLog("InClass,Struct");
  //PushText(yytext);
  g_nGeneralCaller = YY_START;
  BEGIN(ProcessVariable);
}

<InClass,Struct>{ID} {
  OutputLog2("// process a class variable", yytext);

  // If we encounter a inner class (class contained in a class),
  // pClass can be NULL.
  // In that case, just give up further processing and just
  // try not to generate an access violation.
  if(pClass)
    pClass->sVar = yytext;

//  PushText(yytext);

//  g_nGeneralCaller = YY_START;
//  BEGIN(ProcessVariable);

//  g_bParams = true;

//  param_info p ("", yytext,  "", "", false, false, false, false);
//  lstParams.push_back(p);

  BEGIN(ClassVar);

}

<ClassVar>"," {
  OutputLog("// we've got a multiple variable definition");

  if(g_bClassBody)
  {
    BEGIN(InClass);
  }
  else
  {
    BEGIN(Struct);
  }
}

<ClassVar>":" {}	// Eat up the colon

<ClassVar>{ID} {
  OutputLog2("// classvar ID :", yytext);
  ProcessParameterType(yytext);
}

<ClassVar>";" {
  OutputLog("// output the variable definition");

  DisplayVariables();
  g_bParams = false;

  if(g_bClassBody)
  {
    BEGIN(InClass);
  }
  else
  {
    BEGIN(Struct);
  }
}

<ClassPtrVar>{ID} {
  OutputLog2("// classvar id :", yytext);
  pClass->sType = yytext;
}

<ClassPtrVar>";" {
  OutputLog("// output the typedef");
  fprintf(OUTPUT, "typedef %s* %s;\n", pClass->sType.c_str(), pClass->sName.c_str());

  BEGIN(mytype);
}

<Uses>{ID} {

    std::string id( yytext );
    if (!id.compare("uses")) {
        boost::source_location const & loc = BOOST_CURRENT_LOCATION;
        throw_SyntaxError( SE_syntax_keyword.data(), loc);
    }
    g_cProgramCode
    << "# include " << "<" << yytext << ".hpp>"
    << endl;
}
<Uses>; {
    BEGIN ( Body );
}
<Uses>, { }
<Uses>. {
    boost::source_location const & loc = BOOST_CURRENT_LOCATION;
    throw_SyntaxError( SE_syntax_expect_comma.data(), loc);
}

%%

// ---------------------------------------------------------------------------
// Output program version information
// ---------------------------------------------------------------------------
void version_info(void)
{
    stringstream ss;
    ss   << "Pas2Dox version: "
         << ApplicationVersion
         << " "
         << ApplicationDate
         << endl << "Copyright Jens Kallup 2024"
         << endl
         << endl << "Pas2dox is a Pascal/Delphi/Kylix input filter for Doxygen"
         << endl
         << endl << "pas2dox [-hdkiobsnm] <input_file>"
         << endl << " -h - Help Information"
         << endl << " -d - Run In Debug Mode"
         << endl << " -k - Don't Comment Out Function Body"
         << endl << " -i - Process only \'Interface\' section"
         << endl << " -j - JavaDoc processing"
         << endl << " -o - Output to filename.cpp instead of console"
         << endl << " -b - Experimental convert function body to c++"
         << endl << " -s - Suppress generation of \\sa clauses on properties"
         << endl << " -n - Generate enclosing namespace with unit name"
         << endl << " -m - Do not ignore implementation section"
         << endl ;
    cout << ss.str();
}

// ---------------------------------------------------------------------------
// open the input, and output file. output file becomes .cpp
// ---------------------------------------------------------------------------
void cc_file_output( std::string name)
{
    cout << "==> Transpile "
         << name << " to: "
         << name << ".cpp"
         << endl;

    yyin = fopen(name.c_str(), "r");
    
    if (yyin == NULL) {
        stringstream ss;
        ss << "Filename " << name << " Not Found.";
        throw EP_Exception_ExitFailure( ss.str().c_str() );
    }
    
    name += ".cpp";
    
    OUTPUT = fopen(name.c_str(), "w");
    if (OUTPUT == NULL) {
        stringstream ss;
        ss << "Filename " << name << " Not Found.";
        throw EP_Exception_ExitFailure( ss.str().c_str() );
    }
}

void ch_file_output( std::string name)
{
    cout << "ch output: " << name << endl;
}

void cm_file_output( std::string name)
{
    cout << "cm output: " << name << endl;
}

// ---------------------------------------------------------------------------
// locale helper function member as place-holder ...
// ---------------------------------------------------------------------------
#if defined(__MINGW32__) || defined(__MINGW64__)
void SetApplicationLocale( std::string loca, LCID lcid )
{
    std::stringstream ss;
    ss << loca << ".UTF-8";

    SetEnvironmentVariable(
    LPCTSTR( "LC_ALL"),
    LPCTSTR( ss.str().c_str()));

    SetEnvironmentVariable(
    LPCTSTR( "LANG"),
    LPCTSTR( ss.str().c_str()));

    SetEnvironmentVariable(
    LPCTSTR( "LANGUAHE"),
    LPCTSTR( ss.str().c_str()));

    // -------------------------
    // mark locale as "changed"
    // -------------------------
    SetThreadLocale    ( lcid );
    SetThreadUILanguage( lcid );
}
#endif
// ---------------------------------------------------------------------------
// Get the system codepage ...
// ---------------------------------------------------------------------------
int handle_codepage()
{
    #if defined(__MINGW32__) || defined(__MINGW64__)
    WCHAR localeName[LOCALE_NAME_MAX_LENGTH];
    int result = GetUserDefaultLocaleName(
    localeName,
    LOCALE_NAME_MAX_LENGTH);

    // ----------------------------------------------
    // Get the ANSI code page for the current locale
    // ----------------------------------------------
    if (result > 0) {
        int ansiCodePage = GetLocaleInfoEx(
            localeName,
            LOCALE_IDEFAULTANSICODEPAGE,
            NULL,
            0);
        if (ansiCodePage > 0) {
            wchar_t* ansiCodePageBuffer = new wchar_t[ansiCodePage];
            GetLocaleInfoEx(
            localeName,
            LOCALE_IDEFAULTANSICODEPAGE,
            ansiCodePageBuffer,
            ansiCodePage);
            
            std::wstringstream wss;
            wss << "==> Codepage: ansi " << ansiCodePageBuffer;
            
            std::stringstream ss;
            std::wstring wideStr = wss.str();
            
            std::wstring_convert< std::codecvt_utf8< wchar_t >> converter;
            g_bCodepageApplication = converter.to_bytes(wideStr);
            
            std::cout << g_bCodepageApplication <<
            std::endl;
            
            delete [] ansiCodePageBuffer;
            
            return ansiCodePage;
        }

        // ---------------------------------------------
        // Get the OEM code page for the current locale
        // ---------------------------------------------
        int oemCodePage = GetLocaleInfoEx(
            localeName,
            LOCALE_IDEFAULTCODEPAGE,
            NULL,
            0);
        if (oemCodePage > 0) {
            wchar_t* oemCodePageBuffer = new wchar_t[oemCodePage];
            GetLocaleInfoEx(
            localeName,
            LOCALE_IDEFAULTCODEPAGE,
            oemCodePageBuffer,
            oemCodePage);
            
            std::wstringstream wss;
            wss << "==> Codepage: oem " << oemCodePageBuffer;
            
            std::stringstream ss;
            std::wstring wideStr = wss.str();
            
            std::wstring_convert< std::codecvt_utf8< wchar_t >> converter;
            g_bCodepageApplication = converter.to_bytes(wideStr);
            
            std::cout << g_bCodepageApplication <<
            std::endl;
            
            delete [] oemCodePageBuffer;
            
            return oemCodePage;
        }
    }
    else {
        std::cerr << "error: can not get codepage." <<
        std::endl;
    }
    #endif
    return 0;
}
// ---------------------------------------------------------------------------
// perform pre-tasks: de-compress the locale file:
// ---------------------------------------------------------------------------
void handle_locale()
{
    // default: en = English
    std::string locale_str = std::string( "en" );

    // -----------------------------------------------------
    // save old locale
    // -----------------------------------------------------
    #if defined(__MINGW32__) || defined(__MINGW64__)
        LCID lcid  = 0;
        if (GetLocaleInfoEx(
            LOCALE_NAME_USER_DEFAULT,
            LOCALE_RETURN_NUMBER | LOCALE_ILANGUAGE,
            (LPWSTR)&lcid,
            sizeof(lcid)) < 2) {
            
            if (g_bDebugMode)  {
                std::string err( "can not get locale, use default en-US." );
                std::cerr << err <<
                std::endl;
                
                PLOGD << err;
            }
        }
        g_bLocalesSytemLCID = GetThreadLocale();
        
        // -----------------------------------------------------
        // supported locales ...
        // -----------------------------------------------------
        if (lcid == 0x0407) {
            SetConsoleOutputCP(65001); // set codepage UTF-8

            locale_str = "de";
            g_bLocalesApplicationLCID = MAKELCID(
            MAKELANGID(LANG_GERMAN, SUBLANG_GERMAN), SORT_DEFAULT);
            
            SetApplicationLocale( locale_str, g_bLocalesApplicationLCID );
        }
        else {
            SetConsoleOutputCP(65001); // set codepage UTF-8
            
            locale_str = "en";
            g_bLocalesApplicationLCID = MAKELCID(
            MAKELANGID(LANG_ENGLISH,SUBLANG_DEFAULT), SORT_DEFAULT);
            
            SetApplicationLocale(locale_str, g_bLocalesApplicationLCID );
        }
    #else
        setLocale( LC_MESSAGES, locale_str );
    #endif

    // -----------------------------------------------------
    // GETTEXT_DOMAIN => Makefile -DGETTEXT_DOMAIN="pas2dox"
    // -----------------------------------------------------
    bindtextdomain         ( GETTEXT_DOMAIN, "locales" );
    bind_textdomain_codeset( GETTEXT_DOMAIN, "UTF-8"   );
    textdomain             ( GETTEXT_DOMAIN );
}

// ---------------------------------------------------------------------------
// clean-up the workspace ...
// ---------------------------------------------------------------------------
void cleanup()
{
    fclose( yyout );
    fclose( yyin  );
    
    
    exit( g_bExitCode );
}

// ---------------------------------------------------------------------------
// entry point function for our converter
// ---------------------------------------------------------------------------
int main (int argc, char** argv)
{
    options_description desc{"Options"};
    variables_map       vm;
    
    bool bEnd      = false;
    bool bShowHelp = true;

    // ----------------------------------
    // registering the clean-up function
    // ----------------------------------
    if (atexit(cleanup) != 0) {
        std::stringstream ss;
        ss  << "error: can not register cleanup function."
            << ApplicationExeFile;
            
        BOOST_THROW_EXCEPTION(
               boost::enable_error_info(std::runtime_error(ss.str().c_str()))
            << boost::errinfo_api_function("main")
            << boost::errinfo_errno(0)

            << boost::throw_function(__FUNCTION__)
            << boost::throw_file(__FILE__)
            << boost::throw_line(__LINE__));
            
        return (g_bExitCode = EXIT_FAILURE);
    }

    // ----------------------------------
    // if no argument given, display help
    // ----------------------------------
    if (argc < 2) {
        std::cerr << "use --help for help." <<
        std::endl ;
        return (g_bExitCode = EXIT_FAILURE);
    }

    std::set_terminate( boost::core::verbose_terminate_handler );

    // ----------------------------------
    // try to get user locale translation
    // ----------------------------------
    handle_locale  ();
    handle_codepage();
    
    // ----------------------------------
    // read .ini file for custom set's:
    // ----------------------------------
    myini.setMultiLineValues(true);
    myini.load(ApplicationIniFile);
 
    // ----------------------------------
    // initialize logging stuff ...
    // ----------------------------------
    plog::init(plog::debug, ApplicationLogFile.c_str());
    PLOGI << "start application: "
          << ApplicationExeFile;

    // ----------------------------------
    // parse command line args:
    // ----------------------------------
    options_description general("General Options");
        general.add_options()
        ("help,h"  , "Help screen")
        ("locale,l", value< std::string >()->default_value("en"  ), "country locale")
        
        ("debug,d"     , "debug mode")
        ("keep-body,k" , "keep body")
        ("java-doc,j"  , "java documentation")
        ("output,o"    , value< string >()->notifier(cc_file_output), "Output C++ file")
        ("interface,i" , "only interface")
        ("cvt-body,b"  , "convert body")
        ("genss,s"     , "generate \\ss clause")
        ("namespace,n" , "namespace")
        ("noimpl,m"    , "ignore implementation");

    options_description output_long("Output Options (long)");
        output_long.add_options()
        
        ("output-cc", value< string >()->notifier(cc_file_output), "Output C++ file")
        ("output-ch", value< string >()->notifier(ch_file_output), "Output C++ header file")
        ("output-cm", value< string >()->notifier(cm_file_output), "Output C++ main file");
        
    options_description output_short("Output Options (short)");
        output_short.add_options()
        
        ("cc", value< string >()->notifier(cc_file_output), "Output C++ file")
        ("ch", value< string >()->notifier(ch_file_output), "Output C++ header file")
        ("cm", value< string >()->notifier(cm_file_output), "Output C++ main file");
        
    options_description allOptions("All Options");
    allOptions
        .add(general)
        .add(output_long)
        .add(output_short);

    store(parse_command_line(argc, argv, allOptions), vm);
    notify(vm);

    // ----------------------------
    // check given arguments:
    // ----------------------------
    if (vm.count("help")) {
        cout << allOptions << endl;
        throw EP_Exception_ExitHelp("");
    }   else

    if (vm.count("debug"))      { g_bDebugMode            = true ; } else
    if (vm.count("keep-body"))  { g_bKeepBody             = true ; } else
    if (vm.count("java-docj"))  { g_bJavaDoc              = true ; } else
    if (vm.count("interface"))  { g_bInterfaceOnly        = true ; } else
    if (vm.count("cvt-body"))   { g_bConvertBody          = true ; } else
    if (vm.count("gensa"))      { g_bGenerateSa           = false; } else
    if (vm.count("namespace"))  { g_bNamespace            = true ; } else
    if (vm.count("ignoreimpl")) { g_bIgnoreImplementation = true ; } else {

        if (!OUTPUT) {
            version_info();
            return (g_bExitCode = EXIT_FAILURE);
        }
    }

    if (g_bDebugMode) {
        cout << "==> Running In Debug Mode..."
             << endl
             << endl;
    }
    init_asmjit ();

    yyout = OUTPUT;
    yylex();

    cout << g_cProgramCode.str() << endl;
    
    return (g_bExitCode = EXIT_SUCCESS);
}

extern "C" int yywrap() { return 1; }
