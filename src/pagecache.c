/* v0.9 instant reopen: one saved page image per book (page pixels + layout key only).
 * Format: "ZRPG" u32 version, u32 w, u32 h, u64 key, u32 zlen, zlib(4-bit packed pixels).
 * Writes happen on a private low-priority thread; LRU (file mtime) eviction under a byte cap. */
#define _GNU_SOURCE
#include <pthread.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
extern int compress2(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen, int level);
extern int uncompress(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen);
extern unsigned long compressBound(unsigned long sourceLen);

#define PC_MAGIC "ZRPG"
#define PC_VERSION 1u
static char pc_dir[1100];
static uint64_t pc_cap = 20ull << 20;
static pthread_mutex_t pm = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pc = PTHREAD_COND_INITIALIZER;
static int started, pending, busy, quitting;
static unsigned char *job_pix; static int job_w, job_h; static uint64_t job_key; static char job_name[64];
static pthread_t th;

int64_t zr_file_mtime(const char *path){struct stat st;return !stat(path,&st)&&S_ISREG(st.st_mode)?(int64_t)st.st_mtime:0;}

static int ok_name(const char *n){size_t l=strlen(n);return l==19&&!strcmp(n+16,".pg");}
static void evict(const char *keep){
 for(int round=0;round<4096;round++){
  DIR *d=opendir(pc_dir);if(!d)return;struct dirent *e;uint64_t total=0;char victim[1200]="";time_t age=0;
  while((e=readdir(d))){if(!ok_name(e->d_name))continue;char p[1200];snprintf(p,sizeof p,"%s/%s",pc_dir,e->d_name);struct stat st;if(lstat(p,&st)||!S_ISREG(st.st_mode))continue;total+=(uint64_t)st.st_size;
   if(keep&&!strcmp(e->d_name,keep))continue;if(!*victim||st.st_mtime<age){age=st.st_mtime;strcpy(victim,p);}}
  closedir(d);
  if(total<=pc_cap||!*victim){
   if(total>pc_cap&&keep){char p[1200];snprintf(p,sizeof p,"%s/%s",pc_dir,keep);unlink(p);} /* a single page larger than the cap is not kept */
   return;}
  unlink(victim);
 }
}
static int write_page(const char *name,uint64_t key,const unsigned char *pix,int w,int h){
 size_t n=(size_t)w*h,packed=(n+1)/2;unsigned char *q=malloc(packed);if(!q)return -1;
 for(size_t i=0;i<packed;i++){unsigned a=pix[2*i]>>4,b=(2*i+1<n)?pix[2*i+1]>>4:0;q[i]=(unsigned char)(a<<4|b);}
 unsigned long zl=compressBound(packed);unsigned char *z=malloc(24+zl);if(!z){free(q);return -1;}
 int rc=compress2(z+24,&zl,q,packed,1);free(q);if(rc){free(z);return -1;}
 memcpy(z,PC_MAGIC,4);uint32_t v=PC_VERSION,uw=w,uh=h,uz=(uint32_t)zl;memcpy(z+4,&v,4);memcpy(z+8,&uw,4);memcpy(z+12,&uh,4);memcpy(z+16,&key,8);
 /* zlen follows the key; header is 28 bytes */
 unsigned char *f=malloc(28+zl);if(!f){free(z);return -1;}memcpy(f,z,24);memcpy(f+24,&uz,4);memcpy(f+28,z+24,zl);free(z);
 char tmp[1200],fin[1200];snprintf(fin,sizeof fin,"%s/%s",pc_dir,name);snprintf(tmp,sizeof tmp,"%s.tmp",fin);
 int fd=open(tmp,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW|O_CLOEXEC,0600);if(fd<0){free(f);return -1;}
 size_t off=0,tot=28+zl;while(off<tot){ssize_t k=write(fd,f+off,tot-off);if(k<=0)break;off+=(size_t)k;}
 fsync(fd);close(fd);free(f);if(off!=tot||rename(tmp,fin)){unlink(tmp);return -1;}
 evict(name);return (int)tot;
}
static void *writer(void *arg){(void)arg;
 pthread_mutex_lock(&pm);
 for(;;){while(!pending&&!quitting)pthread_cond_wait(&pc,&pm);if(!pending&&quitting)break;
  pending=0;busy=1;char name[64];strcpy(name,job_name);uint64_t key=job_key;int w=job_w,h=job_h;
  unsigned char *pix=malloc((size_t)w*h);if(pix)memcpy(pix,job_pix,(size_t)w*h);
  pthread_mutex_unlock(&pm);
  if(pix){write_page(name,key,pix,w,h);free(pix);}
  pthread_mutex_lock(&pm);busy=0;pthread_cond_broadcast(&pc);}
 pthread_mutex_unlock(&pm);return 0;}

int zr_pc_init(const char *data,uint64_t cap){
 if(cap==0){pc_dir[0]=0;return -1;}
 pc_cap=cap;char c[1100];snprintf(c,sizeof c,"%s/cache",data);mkdir(c,0700);snprintf(pc_dir,sizeof pc_dir,"%s/cache/pages",data);mkdir(pc_dir,0700);
 struct stat st;if(lstat(pc_dir,&st)||!S_ISDIR(st.st_mode)){pc_dir[0]=0;return -1;}
 return 0;}
/* Copies a w*h 8-bit frame (row stride `stride`) and hands it to the writer thread. Never blocks on IO. */
int zr_pc_submit(const char *name,uint64_t key,const unsigned char *fb,int w,int h,int stride){
 if(!*pc_dir||strlen(name)>=sizeof job_name)return -1;
 pthread_mutex_lock(&pm);
 if(!started){pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setstacksize(&a,256*1024);if(pthread_create(&th,&a,writer,0)==0)started=1;pthread_attr_destroy(&a);}
 if(!started||busy){pthread_mutex_unlock(&pm);return -1;}  /* a write is running: skip this (throttled) snapshot */
 if(!job_pix||job_w!=w||job_h!=h){free(job_pix);job_pix=malloc((size_t)w*h);job_w=w;job_h=h;}
 if(!job_pix){pthread_mutex_unlock(&pm);return -1;}
 for(int y=0;y<h;y++)memcpy(job_pix+(size_t)y*w,fb+(size_t)y*stride,w);
 strcpy(job_name,name);job_key=key;pending=1;pthread_cond_broadcast(&pc);pthread_mutex_unlock(&pm);return 0;}
/* Waits for any pending write (exit path). */
void zr_pc_flush(void){pthread_mutex_lock(&pm);while(pending||busy)pthread_cond_wait(&pc,&pm);pthread_mutex_unlock(&pm);}
void zr_pc_stop(void){if(!started)return;zr_pc_flush();pthread_mutex_lock(&pm);quitting=1;pthread_cond_broadcast(&pc);pthread_mutex_unlock(&pm);pthread_join(th,0);started=0;quitting=0;}
/* Loads a page into out (w*h at row stride) only if magic, size and key all match. 0 on success. */
int zr_pc_load(const char *name,uint64_t key,unsigned char *out,int w,int h,int stride){
 if(!*pc_dir)return -1;char p[1200];snprintf(p,sizeof p,"%s/%s",pc_dir,name);
 int fd=open(p,O_RDONLY|O_NOFOLLOW|O_CLOEXEC);if(fd<0)return -1;struct stat st;
 if(fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size<28||st.st_size>(off_t)(8u<<20)){close(fd);return -2;}
 unsigned char *f=malloc((size_t)st.st_size);if(!f){close(fd);return -3;}
 size_t off=0;while(off<(size_t)st.st_size){ssize_t k=read(fd,f+off,(size_t)st.st_size-off);if(k<=0)break;off+=(size_t)k;}close(fd);
 uint32_t v,uw,uh,uz;uint64_t k;memcpy(&v,f+4,4);memcpy(&uw,f+8,4);memcpy(&uh,f+12,4);memcpy(&k,f+16,8);memcpy(&uz,f+24,4);
 if(off!=(size_t)st.st_size||memcmp(f,PC_MAGIC,4)||v!=PC_VERSION||uw!=(uint32_t)w||uh!=(uint32_t)h||(size_t)uz+28!=off){free(f);return -4;}
 if(k!=key){free(f);return -5;}
 size_t n=(size_t)w*h,packed=(n+1)/2;unsigned char *q=malloc(packed);if(!q){free(f);return -3;}
 unsigned long ql=packed;int rc=uncompress(q,&ql,f+28,uz);free(f);if(rc||ql!=packed){free(q);return -6;}
 for(int y=0;y<h;y++){unsigned char *row=out+(size_t)y*stride;for(int x=0;x<w;x++){size_t i=(size_t)y*w+x;unsigned nib=(i&1)?(q[i/2]&15):(q[i/2]>>4);row[x]=(unsigned char)(nib*17);}}
 free(q);utimensat(AT_FDCWD,p,NULL,0);return 0;}
/* Removes a book's saved page (used when its layout key no longer matches). */
void zr_pc_drop(const char *name){if(!*pc_dir)return;char p[1200];snprintf(p,sizeof p,"%s/%s",pc_dir,name);unlink(p);}
