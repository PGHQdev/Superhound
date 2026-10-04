#include <libproc.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv){if(argc!=2)return 2;pid_t pid=(pid_t)strtol(argv[1],NULL,10);if(pid<=0)return 2;struct rusage_info_v4 before={0},after={0};
 if(proc_pid_rusage(pid,RUSAGE_INFO_V4,(rusage_info_t *)&before))return 1;
 sleep(5);
 if(proc_pid_rusage(pid,RUSAGE_INFO_V4,(rusage_info_t *)&after))return 1;
 printf("pid=%d footprint_bytes=%llu resident_bytes=%llu cpu_percent_over_5s=%.4f\n",pid,after.ri_phys_footprint,after.ri_resident_size,(double)((after.ri_user_time-before.ri_user_time)+(after.ri_system_time-before.ri_system_time))/5e9*100);
 return 0;}
