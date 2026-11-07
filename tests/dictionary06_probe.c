#include "dictionary.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define CHECK(x) do{if(!(x)){fprintf(stderr,"CHECK failed %d: %s\n",__LINE__,#x);return 1;}}while(0)
int main(int argc,char**argv){
 if(argc==3){char lemma[128],out[32768];if(!strcmp(argv[2],"invalid")){CHECK(!zrd_open(argv[1]));return 0;}CHECK(zrd_open(argv[1]));CHECK(zrd_define("book",4,lemma,sizeof lemma,out,sizeof out)==0);zrd_close();return 0;}
 CHECK(argc==2);char lemma[128],definition[32768];CHECK(zrd_define("book",4,lemma,sizeof lemma,definition,sizeof definition)==-1);CHECK(zrd_open(argv[1]));
 const char *words[]={"book","reader","kindles","foxes","studies","children","walked","friend,","“Friend,”","reader’s","café","constitution","pneumonoultramicroscopicsilicovolcanoconiosis"};
 const char *roots[]={"book","reader","kindle","fox","study","child","walk","friend","friend","reader","cafe","constitution",NULL};
 for(unsigned i=0;i<sizeof words/sizeof*words;i++){int n=zrd_define(words[i],strlen(words[i]),lemma,sizeof lemma,definition,sizeof definition);if(!roots[i]){CHECK(n==0);continue;}CHECK(n>0);CHECK(!strcmp(lemma,roots[i]));CHECK(strstr(definition,"(")&&strstr(definition,".)"));printf("PASS %s -> %s (%d definition bytes)\n",words[i],lemma,n);}
 char tiny[4];CHECK(zrd_define("book",4,lemma,sizeof lemma,tiny,sizeof tiny)==0);CHECK(tiny[0]==0);
 clock_t start=clock();for(int i=0;i<10000;i++)CHECK(zrd_define("ghosts",6,lemma,sizeof lemma,definition,sizeof definition)>0);
 printf("PASS 10000 exact/inflected offline lookups: %.6f ms/lookup on box; mmap only, no network/write\n",1000.0*(clock()-start)/CLOCKS_PER_SEC/10000);
 zrd_close();CHECK(zrd_define("book",4,lemma,sizeof lemma,definition,sizeof definition)==-1);CHECK(!zrd_open("tests/fixture.epub"));
 return 0;
}
