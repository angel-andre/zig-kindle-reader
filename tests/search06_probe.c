#include "render.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(x) do {if(!(x)){fprintf(stderr,"CHECK %d: %s\n",__LINE__,#x);return 1;}}while(0)
static zr_hit hits[200];static char snippets[65536];
static int count(zr_doc*z,const char*q){int n=0;for(int p=0;p<zr_page_count(z);p++){int k=zr_search_page(z,p,q,hits,200,snippets,sizeof snippets);if(k<0)return -1;n+=k;}return n;}
int main(){
 zr_doc*z=zr_open("../testbooks/digital-small1.pdf",1272.f*72/300,1696.f*72/300,9,18);CHECK(z);
 int n=zr_search_page(z,6,"EDGAR ALLAN MITCHELL",hits,200,snippets,sizeof snippets);CHECK(n==1);CHECK(hits[0].nq>0);CHECK(hits[0].len>0);snippets[hits[0].off+hits[0].len]=0;CHECK(strstr(snippets+hits[0].off,"Edgar"));
 CHECK(zr_search_page(z,6,"zzzzzzzzz",hits,200,snippets,sizeof snippets)==0);CHECK(zr_search_page(z,6,"",hits,200,snippets,sizeof snippets)==0);zr_close(z);
 z=zr_open("tests/tall-view-fixture.pdf",300,400,9,18);CHECK(z);CHECK(count(z,"row 085")==2);CHECK(zr_search_page(z,0,"row 085",hits,200,snippets,sizeof snippets)==1);snippets[hits[0].off+hits[0].len]=0;CHECK(strstr(snippets+hits[0].off,"row 085"));CHECK(strstr(snippets+hits[0].off,"row 084")==NULL);CHECK(zr_search_page(z,0,"row",hits,7,snippets,sizeof snippets)==7);zr_close(z);
 z=zr_open("tests/anchor-fixture.epub",1272.f*72/300,1696.f*72/300,9,18);CHECK(z);CHECK(count(z,"quiet")==126);zr_set_spacing(z,1.7);zr_relayout(z,1272.f*72/300,1696.f*72/300,30,36,0);CHECK(count(z,"QUIET")==126);zr_close(z);
 puts("PASS case-insensitive PDF phrase + context/geometry, unknown/empty query, bounded matches, fit-width target and 126 EPUB hits before/after reflow");return 0;
}
