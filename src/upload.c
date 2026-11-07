/* v0.9.1 Wi-Fi book upload: a tiny HTTP server that exists only while the Upload
 * screen is open. One port, one connection at a time, PDF/EPUB only, size cap,
 * free-space floor, safe names, temp file + rename into the books folder. */
#define _GNU_SOURCE
#include <pthread.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>
#include <dirent.h>

static pthread_mutex_t um=PTHREAD_MUTEX_INITIALIZER;
static pthread_t uth;static int running,stop_flag,lfd=-1,firewall_open,uport,client=-1;
static char books[1100],exportdir[1200];static uint64_t max_bytes,min_free;
static char status[256]="Starting";static unsigned revision,saved;

static void set_status(const char *fmt,const char *a,long long b){pthread_mutex_lock(&um);snprintf(status,sizeof status,fmt,a,b);revision++;pthread_mutex_unlock(&um);}
unsigned zr_up_revision(void){pthread_mutex_lock(&um);unsigned r=revision;pthread_mutex_unlock(&um);return r;}
unsigned zr_up_saved(void){pthread_mutex_lock(&um);unsigned r=saved;pthread_mutex_unlock(&um);return r;}
int zr_up_running(void){return running;}
void zr_up_status(char *out,int cap){pthread_mutex_lock(&um);snprintf(out,(size_t)cap,"%s",status);pthread_mutex_unlock(&um);}

/* LAN IPv4 address (wlan0 preferred), or empty when not on Wi-Fi. */
int zr_up_address(char *out,int cap){struct ifaddrs *ia,*p;out[0]=0;if(getifaddrs(&ia))return -1;
 for(int pass=0;pass<2&&!out[0];pass++)for(p=ia;p;p=p->ifa_next){if(!p->ifa_addr||p->ifa_addr->sa_family!=AF_INET||(p->ifa_flags&IFF_LOOPBACK)||!(p->ifa_flags&IFF_UP))continue;
  if(pass==0&&strncmp(p->ifa_name,"wlan",4))continue;inet_ntop(AF_INET,&((struct sockaddr_in*)p->ifa_addr)->sin_addr,out,(socklen_t)cap);break;}
 freeifaddrs(ia);return out[0]?0:-1;}

/* Device only: allow the one upload port through the stock firewall while open; removed on stop. */
static void iptables(const char *op){char port[16];snprintf(port,sizeof port,"%d",uport);
 pid_t p=fork();if(p==0){int n=open("/dev/null",O_RDWR);if(n>=0){dup2(n,1);dup2(n,2);}execlp("iptables","iptables",op,"INPUT","-p","tcp","--dport",port,"-j","ACCEPT",(char*)0);_exit(127);}
 if(p<0)return;for(int i=0;i<60;i++){int st;if(waitpid(p,&st,WNOHANG)==p)return;struct timespec t={0,50000000};nanosleep(&t,0);}kill(p,9);waitpid(p,0,0);}

/* Returns 0 and the cleaned name for an acceptable file name; otherwise a reason. */
const char *zr_up_check_name(const char *raw,char *out,size_t cap){
 char d[512];size_t n=0;
 for(const char *s=raw;*s&&n<sizeof d-1;s++){if(*s=='%'&&isxdigit((unsigned char)s[1])&&isxdigit((unsigned char)s[2])){char h[3]={s[1],s[2],0};d[n++]=(char)strtol(h,0,16);s+=2;}else if(*s=='+')d[n++]=' ';else d[n++]=*s;}
 d[n]=0;if(!n||n>200)return "bad name length";
 for(size_t i=0;i<n;i++){unsigned char c=(unsigned char)d[i];if(c<0x20||c==0x7f||c=='/'||c=='\\'||c==':'||c=='*'||c=='?'||c=='"'||c=='<'||c=='>'||c=='|')return "name has forbidden characters";}
 if(d[0]=='.'||d[0]==' '||strstr(d,".."))return "name not allowed";
 const char *dot=strrchr(d,'.');static const char *ok[]={".pdf",".epub",".mobi",".azw3",".txt",".cbz",".fb2",0};int good=0;if(dot)for(int i=0;ok[i];i++)if(!strcasecmp(dot,ok[i]))good=1;if(!good)return "only .pdf, .epub, .mobi, .azw3, .txt, .cbz and .fb2 files";
 if(dot==d)return "name not allowed";
 if(strlen(d)>=cap)return "bad name length";strcpy(out,d);return 0;}

/* v0.9.6: highlights/notes download (Markdown files the reader just wrote to
 * DATA/export). Read-only, .md names only, no paths; served only while the
 * Upload screen is open, like the upload page itself. */
void zr_up_set_export(const char *dir){pthread_mutex_lock(&um);snprintf(exportdir,sizeof exportdir,"%s",dir);pthread_mutex_unlock(&um);}
static int export_name(const char *raw,char *out,size_t cap){char d[512];size_t n=0;
 for(const char *s=raw;*s&&*s!='?'&&n<sizeof d-1;s++){if(*s=='%'&&isxdigit((unsigned char)s[1])&&isxdigit((unsigned char)s[2])){char h[3]={s[1],s[2],0};d[n++]=(char)strtol(h,0,16);s+=2;}else d[n++]=*s;}
 d[n]=0;if(!n||n>240||d[0]=='.'||strstr(d,"..")||strchr(d,'/')||strchr(d,'\\'))return -1;
 for(size_t i=0;i<n;i++)if((unsigned char)d[i]<0x20)return -1;
 if(n<4||strcmp(d+n-3,".md"))return -1;if(n>=cap)return -1;strcpy(out,d);return 0;}
static void html_esc(char *o,size_t cap,const char *s){size_t n=0;for(;*s&&n+7<cap;s++){const char *r=0;if(*s=='&')r="&amp;";else if(*s=='<')r="&lt;";else if(*s=='>')r="&gt;";else if(*s=='"')r="&quot;";else if(*s=='\'')r="&#39;";
 if(r){size_t l=strlen(r);memcpy(o+n,r,l);n+=l;}else o[n++]=*s;}o[n]=0;}
static void url_esc(char *o,size_t cap,const char *s){size_t n=0;for(;*s&&n+4<cap;s++){unsigned char c=(unsigned char)*s;if(isalnum(c)||c=='-'||c=='_'||c=='.'||c=='~')o[n++]=(char)c;else n+=(size_t)snprintf(o+n,cap-n,"%%%02X",c);}o[n]=0;}
static int cmpstr(const void *a,const void *b){return strcmp(*(char*const*)a,*(char*const*)b);}
/* Appends the download list to buf (NUL-terminated, cap bytes). */
static void export_list(char *buf,size_t cap){char dir[1200];pthread_mutex_lock(&um);snprintf(dir,sizeof dir,"%s",exportdir);pthread_mutex_unlock(&um);
 size_t n=strlen(buf);n+=(size_t)snprintf(buf+n,cap-n,"<h2>Highlights and notes</h2>");
 DIR *d=dir[0]?opendir(dir):0;char *names[400];int k=0;
 if(d){struct dirent *e;while((e=readdir(d))&&k<400){size_t l=strlen(e->d_name);if(l>3&&e->d_name[0]!='.'&&!strcmp(e->d_name+l-3,".md"))names[k++]=strdup(e->d_name);}closedir(d);}
 if(!k){snprintf(buf+n,cap-n,"<p>No highlights or notes yet.</p>");return;}
 qsort(names,(size_t)k,sizeof *names,cmpstr);
 n+=(size_t)snprintf(buf+n,cap-n,"<p>Markdown (.md) or plain text (.txt); each file is one book. Nothing is sent anywhere unless you download it.</p><ul>");
 for(int pass=0;pass<2;pass++)for(int i=0;i<k;i++){int all=!strncmp(names[i],"All books - ",12);if(all!=!pass)continue;
  char h[800],u[1400],t[300];size_t l=strlen(names[i]);snprintf(t,sizeof t,"%.*s",(int)(l-3),names[i]);html_esc(h,sizeof h,t);url_esc(u,sizeof u,names[i]);
  if(n+3000<cap)n+=(size_t)snprintf(buf+n,cap-n,"<li>%s%s%s: <a href='/export/%s'>Markdown</a> &middot; <a href='/export/%s?txt'>Text</a></li>",all?"<b>":"",h,all?"</b>":"",u,u);}
 snprintf(buf+n,cap-n,"</ul>");for(int i=0;i<k;i++)free(names[i]);}
static void send_export(int c,const char *target){char name[256],path[1500];
 if(export_name(target+8,name,sizeof name)){const char *m="not found";char h[300];int n=snprintf(h,sizeof h,"HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: %zu\r\nConnection: close\r\n\r\n",strlen(m));if(write(c,h,(size_t)n)>0&&write(c,m,strlen(m))){}return;}
 int txt=strchr(target,'?')&&!strcmp(strchr(target,'?'),"?txt");
 pthread_mutex_lock(&um);snprintf(path,sizeof path,"%s/%s",exportdir,name);pthread_mutex_unlock(&um);
 int fd=open(path,O_RDONLY|O_NOFOLLOW|O_CLOEXEC);struct stat st;
 if(fd<0||fstat(fd,&st)||!S_ISREG(st.st_mode)){if(fd>=0)close(fd);const char *m="not found";char h[300];int n=snprintf(h,sizeof h,"HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: %zu\r\nConnection: close\r\n\r\n",strlen(m));if(write(c,h,(size_t)n)>0&&write(c,m,strlen(m))){}return;}
 char base[256];snprintf(base,sizeof base,"%.*s%s",(int)(strlen(name)-3),name,txt?".txt":".md");char ub[800];url_esc(ub,sizeof ub,base);
 char h[1400];int n=snprintf(h,sizeof h,"HTTP/1.1 200 OK\r\nContent-Type: %s; charset=utf-8\r\nContent-Length: %lld\r\nContent-Disposition: attachment; filename*=UTF-8''%s\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n",txt?"text/plain":"text/markdown",(long long)st.st_size,ub);
 if(write(c,h,(size_t)n)<0){close(fd);return;}char b[16384];ssize_t k;while((k=read(fd,b,sizeof b))>0){if(write(c,b,(size_t)k)!=k)break;}close(fd);}

uint64_t zr_up_free(const char *path){struct statvfs st;if(statvfs(path,&st))return 0;return (uint64_t)st.f_bavail*st.f_frsize;}

static const char PAGE[]="<!doctype html><html><head><meta name=viewport content='width=device-width,initial-scale=1'><title>Zigg Reader upload</title>"
"<style>body{font-family:sans-serif;max-width:32em;margin:2em auto;padding:0 1em}button,input{font-size:1.1em}</style></head><body>"
"<h2>Send books to the Kindle</h2><p>PDF or EPUB only. Books go into the Books folder.</p>"
"<input type=file id=f multiple accept='.pdf,.epub,.mobi,.azw3,.txt,.cbz,.fb2'><p><button onclick='go()'>Upload</button></p><pre id=s></pre>"
"<script>async function go(){const s=document.getElementById('s');for(const f of document.getElementById('f').files){s.textContent+=f.name+': sending...\\n';"
"try{const r=await fetch('/upload?name='+encodeURIComponent(f.name),{method:'POST',body:f});s.textContent+=f.name+': '+(await r.text())+'\\n';}catch(e){s.textContent+=f.name+': failed\\n';}}}</script>";

static void reply(int c,int code,const char *msg,const char *type,const char *body){char h[400];size_t bl=strlen(body);
 int n=snprintf(h,sizeof h,"HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %zu\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n",code,msg,type,bl);
 if(write(c,h,(size_t)n)<0)return;size_t off=0;while(off<bl){ssize_t k=write(c,body+off,bl-off);if(k<=0)break;off+=(size_t)k;}}

static void handle(int c){
 struct timeval tv={20,0};setsockopt(c,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);setsockopt(c,SOL_SOCKET,SO_SNDTIMEO,&tv,sizeof tv);
 char hdr[8192];size_t n=0;char *end=0;
 while(n<sizeof hdr-1){ssize_t k=read(c,hdr+n,sizeof hdr-1-n);if(k<=0)return;n+=(size_t)k;hdr[n]=0;if((end=strstr(hdr,"\r\n\r\n")))break;}
 if(!end){reply(c,431,"Header Too Large","text/plain","header too large");return;}
 char method[8]="",target[1100]="";if(sscanf(hdr,"%7s %1099s",method,target)!=2){reply(c,400,"Bad Request","text/plain","bad request");return;}
 if(!strcmp(method,"GET")&&(!strcmp(target,"/")||!strncmp(target,"/?",2))){static char page[262144];snprintf(page,sizeof page,"%s",PAGE);export_list(page,sizeof page-32);strcat(page,"</body></html>");reply(c,200,"OK","text/html; charset=utf-8",page);return;}
 if(!strcmp(method,"GET")&&!strncmp(target,"/export/",8)){send_export(c,target);return;}
 if(strcmp(method,"POST")||strncmp(target,"/upload?name=",13)){reply(c,404,"Not Found","text/plain","not found");return;}
 char name[256];const char *why=zr_up_check_name(target+13,name,sizeof name);
 if(why){set_status("Refused a file: %s",why,0);reply(c,400,"Bad Request","text/plain",why);return;}
 long long len=-1;for(char *p=hdr;p<end;){char *nl=strstr(p,"\r\n");if(!nl)break;if(!strncasecmp(p,"Content-Length:",15))len=atoll(p+15);if(!strncasecmp(p,"Transfer-Encoding:",18)){reply(c,411,"Length Required","text/plain","length required");return;}p=nl+2;}
 if(len<=0){reply(c,411,"Length Required","text/plain","length required");return;}
 if((uint64_t)len>max_bytes){set_status("Refused %s: too large",name,0);reply(c,413,"Too Large","text/plain","file too large");return;}
 uint64_t fr=zr_up_free(books);
 if(fr<min_free||fr-min_free<(uint64_t)len){set_status("Refused %s: would leave less than the free-space minimum",name,0);reply(c,507,"Insufficient Storage","text/plain","refused: not enough free space would remain on the Kindle");return;}
 char tmp[1300],fin[1400];snprintf(tmp,sizeof tmp,"%s/.zr-upload-%d.part",books,(int)getpid());
 int fd=open(tmp,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW|O_CLOEXEC,0644);if(fd<0){reply(c,500,"Error","text/plain","cannot write");return;}
 size_t body0=(size_t)(end+4-hdr),have=n-body0;long long got=0;int ok=1;
 if(have>(size_t)len)have=(size_t)len;
 if(have&&write(fd,end+4,have)!=(ssize_t)have)ok=0;got=(long long)have;
 char buf[65536];time_t last=0;
 while(ok&&got<len&&!stop_flag){size_t want=sizeof buf;if((long long)want>len-got)want=(size_t)(len-got);ssize_t k=read(c,buf,want);if(k<=0){ok=0;break;}
  if(write(fd,buf,(size_t)k)!=k){ok=0;break;}got+=k;time_t now=time(0);if(now!=last){last=now;set_status("Receiving %s: %lld%%",name,got*100/len);}}
 if(ok&&got==len)ok=fsync(fd)==0;close(fd);
 if(!ok||got!=len){unlink(tmp);set_status("Upload of %s did not finish",name,0);if(!stop_flag)reply(c,400,"Bad Request","text/plain","incomplete upload");return;}
 /* never overwrite: add " (2)".. before the extension */
 snprintf(fin,sizeof fin,"%s/%s",books,name);struct stat st;
 if(!lstat(fin,&st)){const char *dot=strrchr(name,'.');int i;for(i=2;i<100;i++){snprintf(fin,sizeof fin,"%s/%.*s (%d)%s",books,(int)(dot-name),name,i,dot);if(lstat(fin,&st))break;}if(i==100){unlink(tmp);reply(c,409,"Conflict","text/plain","name in use");return;}}
 if(rename(tmp,fin)){unlink(tmp);reply(c,500,"Error","text/plain","cannot save");return;} /* FAT has no link(); one connection at a time, name checked free just above */
 pthread_mutex_lock(&um);saved++;pthread_mutex_unlock(&um);
 const char *base=strrchr(fin,'/')+1;set_status("Saved %s",base,0);reply(c,200,"OK","text/plain","saved");}

static void *server(void *a){(void)a;
 while(!stop_flag){struct pollfd p={lfd,POLLIN,0};int r=poll(&p,1,200);if(r<=0)continue;int c=accept4(lfd,0,0,SOCK_CLOEXEC);if(c<0)continue;pthread_mutex_lock(&um);client=c;pthread_mutex_unlock(&um);if(!stop_flag)handle(c);pthread_mutex_lock(&um);client=-1;pthread_mutex_unlock(&um);shutdown(c,SHUT_RDWR);close(c);}
 return 0;}

/* Starts the server on port (all interfaces). 0 on success. */
int zr_up_start(const char *books_dir,int port,uint64_t max,uint64_t free_floor,int device){
 if(running)return 0;snprintf(books,sizeof books,"%s",books_dir);max_bytes=max;min_free=free_floor;uport=port;stop_flag=0;saved=0;
 lfd=socket(AF_INET,SOCK_STREAM|SOCK_CLOEXEC,0);if(lfd<0)return -1;int one=1;setsockopt(lfd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof one);
 struct sockaddr_in sa={0};sa.sin_family=AF_INET;sa.sin_port=htons((uint16_t)port);sa.sin_addr.s_addr=htonl(INADDR_ANY);
 if(bind(lfd,(struct sockaddr*)&sa,sizeof sa)||listen(lfd,2)){close(lfd);lfd=-1;return -2;}
 if(device){iptables("-I");firewall_open=1;}
 if(pthread_create(&uth,0,server,0)){close(lfd);lfd=-1;if(firewall_open){iptables("-D");firewall_open=0;}return -3;}
 running=1;set_status("Waiting for a file","",0);return 0;}
void zr_up_stop(void){if(!running)return;stop_flag=1;pthread_mutex_lock(&um);if(client>=0)shutdown(client,SHUT_RDWR);pthread_mutex_unlock(&um);pthread_join(uth,0);close(lfd);lfd=-1;running=0;if(firewall_open){iptables("-D");firewall_open=0;}
 char tmp[1300];snprintf(tmp,sizeof tmp,"%s/.zr-upload-%d.part",books,(int)getpid());unlink(tmp);}
