/* MuPDF's case-insensitive search, preserving each match's multi-line quads.
 * Search is stepped one page per UI loop, not one blocking scan of the book. */
struct zr_search_ctx { zr_hit *hits; int n,max; char *snips; int cap,used; zr_word *words; int nw; char *text; };
static int zr_search_callback(fz_context *ctx,void *opaque,int n,fz_quad *qs)
{
 struct zr_search_ctx *s=opaque;if(s->n>=s->max)return 1;zr_hit*h=s->hits+s->n++;h->nq=n<8?n:8;
 int first=-1,last=-1;
 for(int k=0;k<h->nq;k++){
  fz_rect r=fz_rect_from_quad(qs[k]);h->q[k][0]=r.x0;h->q[k][1]=r.y0;h->q[k][2]=r.x1;h->q[k][3]=r.y1;
  for(int i=0;i<s->nw;i++){zr_word*w=s->words+i;if(fminf(r.x1,w->x1)>fmaxf(r.x0,w->x0)&&fminf(r.y1,w->y1)-fmaxf(r.y0,w->y0)>0.5f*fminf(r.y1-r.y0,w->y1-w->y0)){if(first<0)first=i;last=i;}}
 }
 h->off=s->used;
 if(first>=0){int a=first>4?first-4:0,b=last+9<s->nw?last+9:s->nw;
  for(int i=a;i<b;i++){zr_word*w=s->words+i;if(s->used+w->len+1>=s->cap||s->used-h->off+w->len+1>250)break;if(i>a)s->snips[s->used++]=' ';memcpy(s->snips+s->used,s->text+w->off,w->len);s->used+=w->len;}}
 h->len=s->used-h->off;return s->n>=s->max;
}
int zr_search_page(zr_doc*z,int page,const char*needle,zr_hit*hits,int max,char*snippets,int cap)
{
 if(!needle||!*needle||max<=0||cap<=0)return 0;fz_context*ctx=z->ctx;fz_stext_page*st=NULL;zr_word*ws=NULL;char*text=NULL;
 struct zr_search_ctx s={.hits=hits,.max=max,.snips=snippets,.cap=cap};fz_var(st);fz_var(ws);fz_var(text);fz_var(s);
 fz_try(ctx){fz_stext_options opts={0};st=fz_new_stext_page_from_display_list(ctx,get_list(z,page),&opts);ws=fz_malloc_array(ctx,12000,zr_word);text=fz_malloc(ctx,262144);int tl=0,line=0;
  words_block(st->first_block,ws,12000,text,262144,&s.nw,&tl,&line);s.words=ws;s.text=text;fz_search_stext_page_cb(ctx,st,needle,zr_search_callback,&s);
 }
 fz_always(ctx){fz_drop_stext_page(ctx,st);fz_free(ctx,ws);fz_free(ctx,text);}
 fz_catch(ctx){fz_report_error(ctx);return -1;}
 return s.n;
}
