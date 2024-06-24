%{
#include <stdio.h>
#include <string.h>

#include "ruler.h"

#define YYSTYPE char *
%}

%token CRITERION EQUALS STRING NEWLINE COMMAND END
%start input
%defines
%error-verbose

%%
input: /* this allows blank line before first rulerrc token */
	| input NEWLINE
	| input block_list
	;

block_list: block
	| block_list NEWLINE
	| block_list block
	| block_list END
	{ return 0; }
	;

block: descriptor_list command
	{
		block();
	}
	;

descriptor_list: descriptor
	| descriptor_list descriptor
	| descriptor_list NEWLINE
	;

command: COMMAND
	{
		comm($1);
	}
	;

descriptor: CRITERION EQUALS STRING
	{
		desc($1, $3);
	}
	;
%%

void
yyerror(const char *str)
{
	fprintf(stderr, "error: %s\n", str);
}

int
yywrap()
{
	return 1;
}
