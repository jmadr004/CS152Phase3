%{
 #include <stdio.h>
 #include <stdlib.h>
 #include <cstring>
 #include <vector>
 #include <iostream>
 #include <vector> 
 #include <string>
 #include <sstream>
 using namespace std;
 
 void yyerror(const char *msg);
 extern int currLine;
 extern int currPos;
 extern FILE * yyin;
 int yylex(void);
 
 int tempCount = 0;
 int labelCount = 0;
 vector <string> variables;
 vector <string> equations;
 vector <string> CallStack;
 vector <string> TempStack;
 vector <string> code;
 vector <string> tempSave;
 
 void mathOp(string);
 void allocSpace();
 int lastSpaceOpen();
 
%}

%union{
  double dval;
  int ival;
  char* str;
}

%error-verbose
%start program
%token <str> MULT DIV PLUS MINUS MOD EQUAL L_PAREN R_PAREN END
%token <str> PROGRAM BEGIN_PROGRAM END_PROGRAM ELSEIF FUNCTION BEGIN_PARAMS END_PARAMS
%token <str> BEGIN_LOCALS END_LOCALS BEGIN_BODY END_BODY INTEGER ARRAY
%token <str> OF IF THEN ENDIF ELSE WHILE DO FOREACH IN BEGINLOOP ENDLOOP CONTINUE
%token <str> READ WRITE AND OR NOT TRUE FALSE RETURN
%token <str> EQ NEQ LT GT LTE GTE SEMICOLON COLON COMMA L_SQUARE_BRACKET R_SQUARE_BRACKET
%token <str> ASSIGN 
%token <dval> NUMBER
%token <str> IDENTIFIER

%type <str> idents
%type <str> ident
%type <str> relation-exp
%type <str> expression
%type <str> mult-exp
%type <str> term
%type <str> var
%type <str> paramDecl
%type <str> declaration

%left PLUS MINUS
%left MULT DIV
%nonassoc NOT
%nonassoc UMINUS


%% 
program       :   functions 
              ;
        
functions    :    
              |   function functions 
              ;

function      :  FUNCTION  ident SEMICOLON {
                   cout << "func " << variables.back() << endl; 
                   variables.pop_back();
                 } BEGIN_PARAMS paramDecls END_PARAMS BEGIN_LOCALS declarations END_LOCALS BEGIN_BODY statements END_BODY {
                   for(int i = 0; i < code.size(); i++){
                     cout << code.at(i) << endl;
                   }
                   code.clear();
                   cout << "endfunc\n\n";
                 }
              ;

paramDecls   :  
              |   paramDecl SEMICOLON paramDecls
              ;
        
paramDecl    :	idents COLON INTEGER  {
                  cout << ". " << variables.back() << endl;
                  cout << "= " << variables.back() << ", $0" << endl; 
                  variables.pop_back();
                } 
              | idents COLON ARRAY L_SQUARE_BRACKET NUMBER[num] R_SQUARE_BRACKET OF INTEGER {
                  cout << ".[] " << variables.back() << ", " << $num << endl;
                  variables.pop_back();
                }  
	      ;

declarations :  
              |   declaration SEMICOLON declarations
              ;
        
declaration  :	idents COLON INTEGER {
                  for( int i = 0; i < variables.size(); i++){
                    cout << ". " << variables.at(i) << endl;
                  }
                  variables.clear();
                }
              | idents COLON ARRAY L_SQUARE_BRACKET NUMBER[num] R_SQUARE_BRACKET OF INTEGER {
                  cout << ".[] " << variables.back() << ", " << $num << endl;
                  variables.pop_back();
                }  
		          ;
                       
statements   :   
              |  statement SEMICOLON statements 
              ;
                       
statement    :    var ASSIGN expression {
                    if(variables.back() == "[]"){ 
                      variables.pop_back();
                      string temp2 = TempStack.back();
                      TempStack.pop_back();
                      string temp1 = TempStack.back();
                      TempStack.pop_back();
                      
                      code.push_back("[]= " + variables.back() + ", " + temp1 + ", " + temp2);
                      variables.pop_back();
                    }
                    else {
                      code.push_back("= " + variables.back() + ", " + TempStack.back());
                      variables.pop_back();
                      TempStack.pop_back();
                    }
                  }
              |   IF bool-exp {allocSpace();} THEN statement SEMICOLON statements ENDIF {
                    code.push_back(": __label__" + to_string(labelCount+1));
                  	code.at(lastSpaceOpen()) = ": __label__" + to_string(labelCount);
                  	code.at(lastSpaceOpen()) = ":= __label__" + to_string(labelCount+1);
                  	code.at(lastSpaceOpen()) = "?:= __label__" + to_string(labelCount) + ", " + tempSave.back();
                  	labelCount+=2;
                  	tempSave.pop_back();                    
                  }
              |   IF bool-exp {allocSpace();} THEN statement SEMICOLON statements ELSE statements ENDIF { 
              
                  }                
              |   WHILE {code.push_back("OPEN_SPACE");} bool-exp {allocSpace();} BEGINLOOP statement SEMICOLON statements ENDLOOP{
                    code.push_back(":= __label__" + to_string(labelCount+2));
                    code.push_back(": __label__" + to_string(labelCount+1));
                  	code.at(lastSpaceOpen()) = ": __label__" + to_string(labelCount);
                  	code.at(lastSpaceOpen()) = ":= __label__" + to_string(labelCount+1);
                  	code.at(lastSpaceOpen()) = "?:= __label__" + to_string(labelCount) + ", " + tempSave.back();
                    code.at(lastSpaceOpen()) = ": __label__" + to_string(labelCount+2);
                  	labelCount+=3;
                  	tempSave.pop_back();                                                
                  }
              |   DO BEGINLOOP statement SEMICOLON statements ENDLOOP WHILE bool-exp                
              |   READ vars {
                    code.push_back(".< " + variables.back());
                    variables.pop_back();
                  }
              |   WRITE vars {
                    code.push_back(".> " + variables.back());
                    variables.pop_back();
                  }
              |   CONTINUE 
              |   RETURN expression {
                    code.push_back("ret " + TempStack.back());
                    TempStack.pop_back();
                  } 
              ;
              
vars         :    var 
              |   vars COMMA var 
              ;
      
var          :    ident  
              |   ident L_SQUARE_BRACKET expression R_SQUARE_BRACKET {
                    variables.push_back("[]");
                  }
              ;

bool-exp      :   relation-and-exp 
              |   bool-exp OR relation-and-exp  
              ;

relation-and-exp :  relation-exp 
                  |  relation-and-exp AND relation-exp 
                  ;

relation-exp  :  NOT relation-exp %prec NOT 
              |  expression comp expression {
                  string temp = "__temp__" + to_string(tempCount);
                  string src2 = TempStack.back();
                   TempStack.pop_back();
                  string src1 = TempStack.back();
                   TempStack.pop_back();
                   
                  code.push_back(". " + temp);
                  code.push_back(equations.back() + temp + ", " + src1 + ", " + src2);
                  //cout << ". " << temp << endl;
                  //cout << equations.back() << temp << ", " << src1 << ", " << src2 << endl; 
                  
                  equations.pop_back();
                  TempStack.push_back(temp);
                  tempCount++;
                }
              |  TRUE  
              |  FALSE  
              |  L_PAREN bool-exp R_PAREN 
              ;

comp         :   EQ   {equations.push_back("== ");} 
              |  NEQ  {equations.push_back("!= ");} 
              |  LT   {equations.push_back("< ");} 
              |  GT   {equations.push_back("> ");} 
              |  LTE  {equations.push_back("<= ");} 
              |  GTE  {equations.push_back(">= ");} 
              ;
             
expressions   :  expression 
              |  expression COMMA expressions  
              ;        
              
expression   :    mult-exp 
              |   expression PLUS mult-exp {mathOp("+ ");}
              |   expression MINUS mult-exp {mathOp("- ");}
              ;
              
mult-exp     :    term 
              |   mult-exp MULT term {mathOp("* ");}
              |   mult-exp DIV term {mathOp("/ ");}
              |   mult-exp MOD term {mathOp("% ");}
              ;

term         :    MINUS term %prec UMINUS //{++tempCount, cout << "= __temp__ " << (tempCount - 1) << ",  " << $1 << endl;}
              |   NUMBER {
                    string temp = "__temp__" + to_string(tempCount);
                    ostringstream oss;
                    oss << $1;
                    code.push_back(". " + temp);
                    code.push_back("= " + temp + ", " + oss.str());
                    TempStack.push_back(temp);
                    ++tempCount;
                  }
              |   var {
                    string temp = "__temp__" + to_string(tempCount);
                    code.push_back(". " + temp);
                    if(variables.back() == "[]"){
                      variables.pop_back();
                      code.push_back("=[] " + temp + ", " + variables.back() + ", " + TempStack.back());
                      TempStack.pop_back();                      
                    }
                    else {
                      code.push_back("= " + temp + ", " + variables.back());
                    }
                    variables.pop_back();
                    TempStack.push_back(temp);
                    ++tempCount;
                  }
              |   L_PAREN expression R_PAREN 
              |   ident L_PAREN {CallStack.push_back($1);} expressions R_PAREN {
                    code.push_back("param " + TempStack.back());
                    TempStack.pop_back();
                    string temp = "__temp__" + to_string(tempCount);
                    
                    code.push_back(". " + temp);
                    string s = CallStack.back();
                    s = s.substr(0,s.size()-2); //gets rid of L_PAREN
                    code.push_back("call " + s + ", " + temp);
                    
                    TempStack.push_back(temp);
                    CallStack.pop_back();
                    variables.pop_back();
                    tempCount++;
                  } 
              |   ident L_PAREN {CallStack.push_back($1);} R_PAREN {
                    string temp = "__temp__" + to_string(tempCount);
                    
                    code.push_back(". " + temp);
                    string s = CallStack.back();
                    s = s.substr(0,s.size()-2);
                    code.push_back("call " + s + ", " + temp);
                    
                    TempStack.push_back(temp);
                    CallStack.pop_back();
                    variables.pop_back();
                    tempCount++;
                  }                    
              ;
              
idents       :    ident 
              |   ident COMMA idents 
		          ;

              
ident        :    IDENTIFIER    {variables.push_back($1);}
              ;
%%

int main(int argc, char **argv) {
   yyparse();
}

void yyerror(const char *msg) {
   printf("** Line %d, position %d: %s\n", currLine, currPos, msg);
}

void mathOp(string op) {
  string temp = "__temp__" + to_string(tempCount);
  string src2 = TempStack.back();
    TempStack.pop_back();
  string src1 = TempStack.back();
    TempStack.pop_back();
  
  code.push_back(". " + temp);
  code.push_back(op + temp + ", " + src1 + ", " + src2);
  
  TempStack.push_back(temp);
  tempCount++;
}

void allocSpace() {
  tempSave.push_back(TempStack.back());
  TempStack.pop_back();
  code.push_back("OPEN_SPACE");
  code.push_back("OPEN_SPACE");
  code.push_back("OPEN_SPACE"); 
}

int lastSpaceOpen() {
 for(int i = code.size()-1; i >= 0; i--){
   if(code.at(i) == "OPEN_SPACE") {
     return i;
   }
 }
 return -1;
}