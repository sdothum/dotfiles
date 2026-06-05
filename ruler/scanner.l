%{
#include <ctype.h>

#define YYSTYPE char *
#include "y.tab.h"

static void skip_comment(void);
static void skip_blank(void);
%}

%%
^[ \t]*"#".*\n                    return NEWLINE;
("class"|"instance"|"type"|"name"|"role")                  yylval = strdup(yytext); return CRITERION;
=                                 return EQUALS;
\"([^\"\\]*(\\.[^\"\\]*)*)\"      yylval = strdup(yytext); return STRING;
^[ \t]+([^\r\n\t\f ](([^\n\\])|(\\(.|\n)))+)  yylval=strdup(yytext); return COMMAND;
\n                                return NEWLINE;
[[:blank:]]                       skip_blank();
<<EOF>>                           return END;
. { fprintf(stderr, "Ignoring unexpected character '%c'\n", *yytext); }
%%

static void
skip_blank(void)
{
	int c;

	c = input();
	while (isblank(c) && c != EOF)
		c = input();

	unput(c);
}
