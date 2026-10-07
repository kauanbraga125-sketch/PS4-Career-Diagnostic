#include "structure_hunter.h"
#include "plugin_common.h"
#include <orbis/libkernel.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#ifndef DIAG_DIR
#define DIAG_DIR GOLDHEN_PATH "/career_diag"
#endif
#define REPORT DIAG_DIR "/structure_hunter.txt"
#define CHUNK (256u*1024u)
#define MAXV (55u*128u)
#define MAXR 64u
#define VQ_FIND_NEXT 1
#define CPU_READ 1
#define CPU_WRITE 2
#define CPU_EXEC 4

typedef struct { uint64_t header,begin,end; uint32_t stride,pid_off,role_off,count,pid_ok,role_ok,unique; int score; } Result;
static uint8_t chunk[CHUNK], vec[MAXV];
static Result results[MAXR];
static size_t result_count;
static uint64_t headers_checked,vectors_read;
static uint32_t regions_scanned;
static bool has_run;

static int rp(uint64_t a, void *d, size_t n){ struct proc_rw r; memset(&r,0,sizeof(r)); r.address=a;r.data=d;r.length=n;return sys_sdk_proc_rw(&r); }
static uint32_t load32(const uint8_t*p){uint32_t v;memcpy(&v,p,4);return v;}
static uint64_t load64(const uint8_t*p){uint64_t v;memcpy(&v,p,8);return v;}
static bool pidok(uint32_t v){return v>0&&v<10000000u;}
static bool roleok(uint32_t v){return v>=1&&v<=5;}
static bool wall(int fd,const char*s,size_t n){while(n){ssize_t w=write(fd,s,n);if(w<=0)return false;s+=w;n-=(size_t)w;}return true;}

static unsigned unique_pids(const uint8_t*d,unsigned count,unsigned stride,unsigned off){
 unsigned u=0; for(unsigned i=0;i<count;i++){uint32_t p=load32(d+i*stride+off); if(!pidok(p))continue; bool seen=false;
 for(unsigned j=0;j<i;j++) if(load32(d+j*stride+off)==p){seen=true;break;} if(!seen)u++;} return u;
}
static void add(Result r){
 size_t n=result_count<MAXR?result_count:MAXR-1;
 if(result_count<MAXR){results[result_count++]=r;} else if(r.score>results[MAXR-1].score)results[MAXR-1]=r; else return;
 for(size_t i=n;i>0&&results[i].score>results[i-1].score;i--){Result t=results[i-1];results[i-1]=results[i];results[i]=t;}
}
static void analyze(uint64_t header,uint64_t begin,uint64_t end){
 static const uint16_t strides[]={8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,72,80,88,96,104,112,120,128};
 if(end<=begin||end-begin>MAXV)return; size_t bytes=(size_t)(end-begin); if(rp(begin,vec,bytes)!=0)return;
 for(size_t s=0;s<sizeof(strides)/sizeof(strides[0]);s++){unsigned st=strides[s]; if(bytes%st)continue; unsigned c=(unsigned)(bytes/st); if(c<8||c>55)continue;
  unsigned probe=st<32?st:32;
  for(unsigned po=0;po+4<=probe;po+=4){unsigned pk=0;for(unsigned i=0;i<c;i++)if(pidok(load32(vec+i*st+po)))pk++; if(pk*100<c*75)continue;
   unsigned uq=unique_pids(vec,c,st,po); if(uq*100<c*70)continue;
   for(unsigned ro=0;ro+4<=probe;ro+=4){if(ro==po)continue;unsigned rk=0;for(unsigned i=0;i<c;i++)if(roleok(load32(vec+i*st+ro)))rk++;if(rk*100<c*60)continue;
    Result r={header,begin,end,st,po,ro,c,pk,rk,uq,(int)(pk*4+uq*3+rk*5)}; if(c>=18&&c<=35)r.score+=20; add(r);
}}}}
static void save(void){
 mkdir(DIAG_DIR,0777); int fd=open(REPORT,O_WRONLY|O_CREAT|O_TRUNC,0666); if(fd<0)return; char l[512];
 int n=snprintf(l,sizeof(l),"Player Structure Hunter v2200\nMetodo: vetor begin/end/cap -> registros -> playerid + role(1..5). Somente leitura.\nregions=%u headers=%llu vectors=%llu results=%zu\n\n",regions_scanned,(unsigned long long)headers_checked,(unsigned long long)vectors_read,result_count);
 if(n>0&&(size_t)n<sizeof(l))wall(fd,l,(size_t)n);
 for(size_t k=0;k<result_count;k++){Result*r=&results[k];n=snprintf(l,sizeof(l),"%02zu score=%d header=0x%016llX begin=0x%016llX end=0x%016llX count=%u stride=0x%X pid_off=0x%X role_off=0x%X pid_ok=%u/%u unique=%u role_ok=%u/%u\n",k+1,r->score,(unsigned long long)r->header,(unsigned long long)r->begin,(unsigned long long)r->end,r->count,r->stride,r->pid_off,r->role_off,r->pid_ok,r->count,r->unique,r->role_ok,r->count);if(n>0&&(size_t)n<sizeof(l))wall(fd,l,(size_t)n);
  unsigned p=r->count<12?r->count:12; size_t b=(size_t)(r->end-r->begin); if(b<=sizeof(vec)&&rp(r->begin,vec,b)==0)for(unsigned i=0;i<p;i++){n=snprintf(l,sizeof(l),"    rec=%02u addr=0x%016llX playerid=%u role=%u\n",i,(unsigned long long)(r->begin+(uint64_t)i*r->stride),load32(vec+i*r->stride+r->pid_off),load32(vec+i*r->stride+r->role_off));if(n>0&&(size_t)n<sizeof(l))wall(fd,l,(size_t)n);}
 } close(fd);
}
int structure_hunter_scan(void){
 OrbisKernelVirtualQueryInfo inf; void*cur=NULL; uintptr_t last=0; result_count=0;headers_checked=0;vectors_read=0;regions_scanned=0;has_run=true;memset(results,0,sizeof(results));
 NotifyStatic(TEX_ICON_SYSTEM,"[StructureHunter v2200] Procurando estruturas PlayerStatus. Aguarde.");
 while(sceKernelVirtualQuery(cur,VQ_FIND_NEXT,&inf,sizeof(inf))>=0){uintptr_t a=(uintptr_t)inf.start_addr,e=(uintptr_t)inf.end_addr;if(e<=a||e<=last)break;last=e;cur=(void*)e;
  if((inf.prot&(CPU_READ|CPU_WRITE))!=(CPU_READ|CPU_WRITE)||inf.isStack||(inf.prot&CPU_EXEC))continue;regions_scanned++;
  for(uintptr_t p=a;p+24<=e;){size_t amt=(size_t)(e-p);if(amt>CHUNK)amt=CHUNK;if(rp((uint64_t)p,chunk,amt)==0)for(size_t o=0;o+24<=amt;o+=8){uint64_t b=load64(chunk+o),f=load64(chunk+o+8),c=load64(chunk+o+16);if(b<0x10000||f<=b||c<f||f-b>MAXV||c-b>MAXV*4ULL)continue;headers_checked++;vectors_read++;analyze((uint64_t)p+o,b,f);} if(amt<=23)break;p+=amt-16;sceKernelUsleep(1000);}
 } save(); char m[180];snprintf(m,sizeof(m),"[StructureHunter] %zu candidatos. Envie structure_hunter.txt.",result_count);NotifyStatic(TEX_ICON_SYSTEM,m);return (int)result_count;
}
size_t structure_hunter_candidate_count(void){return result_count;}
void structure_hunter_format_status(char*out,size_t cap){if(!out||!cap)return;if(!has_run)snprintf(out,cap,"StructureHunter ainda nao executado.");else snprintf(out,cap,"StructureHunter: %zu candidatos; arquivo structure_hunter.txt.",result_count);}
