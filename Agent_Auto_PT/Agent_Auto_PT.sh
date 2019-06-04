#!/bin/bash
###################################
## auther:liuguanghui
## date:20181112
## work:Agent performance testing
###################################

##审计系统ip
DBA_ip=$1
##DBA rms发包网卡,适用于共存模式
rms_eth_T=$2
##DBA npc,nfw收包网卡,适用于共存模式
rms_eth_R=$3
##打包工具选择: 0 tcpreplay 1 meter_broadcast 2 meter_replay (目前没开放,待补充)
pcap_tool=$4
##pcap包名称
pcap_name=$5
##tcpreplay打包速率模式: 0 given Mbps, 1 given packets/sec
tcpreplay_given=$6
##tcpreplay打包速率
tcpreplay_rate=$7
##tcpreplay打包loop数
tcpreplay_loop=$8
##所打的pcap包内预期sql数
expect_sql=$9
##各个节点包内数据库ip:port是否相同: 0 不同 1 相同
db_ip_and_port=${10}

##自动化性能测试工具home目录
Agent_Auto_PT_home_dir=${11}
##Agent设备ip
Agent_ip=${12}
##打包机ip
tcpreplay_ip=${13}
##打包网卡
tcpreplay_eth_T=${14}
##收包网卡
tcpreplay_eth_R=${15}
##所打的包内数据库ip
db_ip=${16}
##所打的包内数据库port
db_port=${17}

##打包节点数
Node_count=${18}

##第几个打包节点
Node_num=${19}

##主程序传过来的时间串
nowTime=${20}

Agent_Auto_PT_pid=`ps -ef |grep $Agent_Auto_PT_home_dir/Agent_Auto_PT.sh |awk '{print $2}'|head -n 1`
#echo $Agent_Auto_PT_pid
Agent_Auto_PT_flag="/tmp/PT_flag_$Agent_Auto_PT_pid"
#rm -rf /tmp/PT_flag_*
touch $Agent_Auto_PT_flag
echo "touch Agent_Auto_PT_flag Success!"

#DB_View='/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e'
echo $DBA_ip
DBA_RUN_PROCESS_MODE=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "SELECT param_value FROM param_config where param_id=121;"'`
echo "DBA_RUN_PROCESS_MODE:$DBA_RUN_PROCESS_MODE"
if [[ $? != 0 ]];then
	echo "ssh root@$DBA_ip fail!"
elif [ -n $DBA_RUN_PROCESS_MODE ];then
	echo "Get DBA_RUN_PROCESS_MODE Success!"
else
	echo "Get DBA_RUN_PROCESS_MODE fail!"
fi
	
#fi	
#pcap_count=`$Agent_Auto_PT_home_dir/meter_broadcast --mode stat $1|grep "Meter Server IP"|awk '{print $9}'|awk -F: '{print $2}'`
#echo $DBA_RUN_PROCESS_MODE
date_now=`date "+%Y%m%d%H%M%S"`
#echo $date_now 
Agent_report="${Agent_Auto_PT_home_dir}/Agent_report_${nowTime}_${Agent_ip}_Node${Node_num}_${tcpreplay_given}-${tcpreplay_rate}_l-${tcpreplay_loop}_esql$expect_sql.txt"

if [[ ! -d "${Agent_Auto_PT_home_dir}/Agent_report_histry" ]];then
	mkdir ${Agent_Auto_PT_home_dir}/Agent_report_histry
else
	echo "Agent_report_histry文件夹已经存在"
fi

mv -f ${Agent_Auto_PT_home_dir}/Agent_report_20* ${Agent_Auto_PT_home_dir}/Agent_report_histry

##查看各节点系统的kernel版本,版本不一样,ifconfig的输出情况不一样
tcpreplay_kernel_version=`uname -r|awk -F. '{print $(NF-1)}'`
agent_kernel_version=`ssh root@$Agent_ip "uname -r"|awk -F. '{print $(NF-1)}'`
DBA_kernel_version=`ssh root@$DBA_ip "uname -r"|awk -F. '{print $(NF-1)}'`

echo "tcpreplay打包前信息" > $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report

if [[ $tcpreplay_kernel_version != "el7" ]];then
	tcpreplay_Tx_pck_b=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $2}'|awk -F: '{print $2}'`
	tcpreplay_T_d_pck_b=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $4}'|awk -F: '{print $2}'`
else
	tcpreplay_Tx_pck_b=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $3}'`
	tcpreplay_T_d_pck_b=`ifconfig $tcpreplay_eth_T|grep "TX errors"|awk '{print $5}'`
fi

if [[ $Agent_kernel_version != "el7" ]];then
	tcpreplay_Rx_pck_b=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $2}'|awk -F: '{print $2}'`
	tcpreplay_R_d_pck_b=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $4}'|awk -F: '{print $2}'`
else
	tcpreplay_Rx_pck_b=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $3}'`
	tcpreplay_R_d_pck_b=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX errors'"|awk '{print $5}'`
fi

echo "tcpreplay发包网卡的发包数 TX packets:"$tcpreplay_Tx_pck_b >> $Agent_report
echo "tcpreplay收包网卡的收包数 RX packets:"$tcpreplay_Rx_pck_b >> $Agent_report

echo "tcpreplay发包网卡drop包数:"$tcpreplay_T_d_pck_b >> $Agent_report
echo "tcpreplay收包网卡drop包数:"$tcpreplay_R_d_pck_b >> $Agent_report

rm -rf $Agent_Auto_PT_home_dir/Agent_info*

Agent_info_b="Agent_info_b_Node${Node_num}_${Agent_ip}"

mkdir $Agent_Auto_PT_home_dir/${Agent_info_b}
scp -r root@$Agent_ip:/tmp/rmagent/rmagent_info.log $Agent_Auto_PT_home_dir/${Agent_info_b} >>/dev/null  2>&1

Agent_pcap_recv_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "rmagent device report. pcap_recv"|tail -n 1|awk '{print $6}'|awk -F: '{print $2}'`
echo "Agent日志中pcap_recv(网卡收到包数):"$Agent_pcap_recv_b >> $Agent_report

Agent_drop_recv_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "rmagent device report. pcap_recv"|tail -n 1|awk '{print $7}'|awk -F: '{print $2}'`
echo "Agent日志中pcap_drop(网卡丢包数):"$Agent_drop_recv_b >> $Agent_report

Agent_w_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "w_count  ="|grep -v "buf"|tail -n1|awk '{print $5}'`
echo "Agent日志中w_count(缓冲区写包数):"$Agent_w_count_b >> $Agent_report

Agent_r_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "w_count  ="|grep -v "buf"|tail -n1|awk '{print $8}'`
echo "r_count (缓冲区读包数/即发包数):"$Agent_r_count_b >> $Agent_report

Agent_w_full_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "w_full_count ="|tail -n1|awk '{print $5}'`
echo "Agent日志中w_full_count(缓冲区写满次数):"$Agent_w_full_count_b >> $Agent_report

Agent_buf0_w_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "buf\[0\] w_count"|tail -n1|awk '{print $6}'`
echo "Agent日志中buf[0] w_count(缓冲区数据包数):"$Agent_buf0_w_count_b >> $Agent_report

Agent_buf0_r_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "buf\[0\] w_count"|tail -n1|awk '{print $9}'`
echo "Agent日志中buf[0] r_count(数据包发包数):"$Agent_buf0_r_count_b >> $Agent_report

Agent_buf1_w_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "buf\[1\] w_count"|tail -n1|awk '{print $6}'`
echo "Agent日志中buf[1] w_count(缓冲区控制包数):"$Agent_buf1_w_count_b >> $Agent_report

Agent_buf1_r_count_b=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log|grep "buf\[1\] w_count"|tail -n1|awk '{print $9}'`
echo "Agent日志中buf[1] r_count(控制包发包数):"$Agent_buf1_r_count_b >> $Agent_report

rm -rf $Agent_Auto_PT_home_dir/rms_info*

rms_info_b="rms_info_b_Node${Node_num}_${DBA_ip}"

scp -r root@$DBA_ip:/dbfw_capbuf/pdump/rms/runtime/ $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1

rms_info_filename=`ls -l $Agent_Auto_PT_home_dir/${rms_info_b}|tail -n1|awk '{print $9}'`

if [[ $rms_info_filename =~ "." ]];then
	rms_info_filename=${rms_info_filename%.*}
fi

#echo $rms_info_filename
rms_check_count_b=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_b}/$rms_info_filename |grep "check_count ="|tail -n1|awk '{print $3}'`
echo "rms日志check_count(收到总包数):"$rms_check_count_b >> $Agent_report

rms_ctl_count_b=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_b}/$rms_info_filename |grep "check_count ="|tail -n1|awk '{print $6}'`
echo "rms日志ctl_count(控制包数):"$rms_ctl_count_b >> $Agent_report

rms_send_count_b=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_b}/$rms_info_filename |grep "send_count ="|tail -n1|awk '{print $3}'`
echo "rms日志send_count(发送总包数):"$rms_send_count_b >> $Agent_report

rms_fifo_in_failed_count_b=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_b}/$rms_info_filename |grep "fifo_in_failed_count ="|tail -n1|awk '{print $3}'`
echo "rms日志fifo_in_failed_count(写失败次数):"$rms_fifo_in_failed_count_b >> $Agent_report

rms_send_failed_count_b=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_b}/$rms_info_filename |grep "send_failed_count ="|tail -n1|awk '{print $6}'`
echo "rms日志send_failed_count(发送失败包数):"$rms_send_failed_count_b >> $Agent_report

if [[ $DBA_RUN_PROCESS_MODE -eq 0 ]] || [[ $DBA_RUN_PROCESS_MODE -eq 2 ]];then

	if [[ $DBA_kernel_version != "el7" ]];then
		DBA_eth1_T_b=`ssh root@$DBA_ip ifconfig eth1|grep "TX packets"|awk '{print $2}'|awk -F: '{print $2}'`
	else
		DBA_eth1_T_b=`ssh root@$DBA_ip ifconfig eth1|grep "TX packets"|awk '{print $3}'`
	fi

	echo "DBA侧eth1网卡TX packets:"$DBA_eth1_T_b >> $Agent_report

	if [[ $DBA_RUN_PROCESS_MODE -eq 0 ]];then

		if [[ $DBA_kernel_version != "el7" ]];then
			DBA_eth2_R_b=`ssh root@$DBA_ip ifconfig eth2|grep "RX packets"|awk '{print $2}'|awk -F: '{print $2}'`
		else
			DBA_eth2_R_b=`ssh root@$DBA_ip ifconfig eth2|grep "RX packets"|awk '{print $3}'`
		fi

		echo "DBA侧eth2网卡RX packets:"$DBA_eth2_R_b >> $Agent_report
		scp -r root@$DBA_ip:/dev/shm/npc/npc_packet_stats $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1
		npc_rx_pkt_tot_b=`cat $Agent_Auto_PT_home_dir/${rms_info_b}/npc_packet_stats|awk '/rx_pkt_tot/{print $3}'`
		echo "npc状态文件标记处理包数:"$npc_rx_pkt_tot_b >> $Agent_report
	elif [[ $DBA_RUN_PROCESS_MODE -eq 2 ]];then
		scp -r root@$DBA_ip:/dev/shm/dpdk/dpdk_nic_stats $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1
		scp -r root@$DBA_ip:/tmp/dpdk/eth_pci_map $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1

		eth_R_flag=`cat $Agent_Auto_PT_home_dir/${rms_info_b}/eth_pci_map|grep "${rms_eth_R}" |awk -F = '{print $2}'`
		echo "Get eth_R_flag(after tcpreplay):$eth_R_flag Seccess!"
		str_row=`grep -n "$eth_R_flag" $Agent_Auto_PT_home_dir/${rms_info_b}/dpdk_nic_stats|cut -d ':' -f 1`
		str_row=$((str_row+2))
		echo "Get dpdk_nic_stats(after tcpreplay) date str_row:$str_row Seccess!"
                nfw_rx_pkt_tot_b=`sed -n "${str_row}p" $Agent_Auto_PT_home_dir/${rms_info_b}/dpdk_nic_stats |awk '{print $3}'`
                echo "nfw状态文件标记处理包数:"$nfw_rx_pkt_tot_b >> $Agent_report
	fi
elif [[ $DBA_RUN_PROCESS_MODE -eq 1 ]];then
	scp -r root@$DBA_ip:/dev/shm/rms/rms_packet_stats $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1
	rms_rx_pkt_tot_b=`cat $Agent_Auto_PT_home_dir/${rms_info_b}/rms_packet_stats|awk '/rx_pkt_tot/{print $3}'`
	echo "rms状态文件标记处理包数:"$rms_rx_pkt_tot_b >> $Agent_report
fi

#Agent_server_host_ip=`ssh root@${Agent_ip} "cat /usr/local/rmagent/rmagent.ini" |awk -F = '/server_host/{print $2}'`
#echo "Get Agent_server_host:$Agent_server_host_ip Seccess!"
Agent_client_ip=`sed -n '/\[client ip\]/p' $Agent_Auto_PT_home_dir/${Agent_info_b}/rmagent_info.log |tail -n1|awk -F : '{print $NF}'`
echo "Get Agent_client_ip:$Agent_client_ip Seccess!"

scp -r root@$DBA_ip:/dev/shm/rmagent/rmagent_stat_${Agent_client_ip}* $Agent_Auto_PT_home_dir/${rms_info_b} >>/dev/null  2>&1
rmagent_stat_filename=`ls $Agent_Auto_PT_home_dir/${rms_info_b}/rmagent_stat_${Agent_client_ip}*`

Agent_send_packet_count_b=`cat $rmagent_stat_filename|awk -F: '/\[send_packet_count\]/{print $2}'`
echo "Agent_${Agent_client_ip}状态文件标记send包数:"$Agent_send_packet_count_b >> $Agent_report
select_dbid="select database_id from database_addresses where port=$db_port and address=\"$db_ip\""
echo $select_dbid
database_id=`ssh root@$DBA_ip "/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e '$select_dbid'"`
echo "Get database_id=$database_id Seccess"
sql_count_b=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "select sum(count) from inst_db_count;"'`
echo "打包前sql数:"$sql_count_b >> $Agent_report
echo "rm -rf $Agent_Auto_PT_flag"
rm -rf $Agent_Auto_PT_flag

tcpreplay_iplist=`cat $Agent_Auto_PT_home_dir/Agent_Auto_PT.ini |awk -F= '/tcpreplay_ip/{print $2}'|head -n$Node_count`
echo "get tcpreplay list seccess:$tcpreplay_iplist"
while true
do
	Node_flag=$Node_count
	for tp_list in $tcpreplay_iplist
	do
		Agent_Auto_PT_flag_count=`ssh root@$tp_list ls /tmp/|grep "PT_flag_"|wc -l`
		echo "total $Agent_Auto_PT_flag_count Node get date!"
		if [[ $Agent_Auto_PT_flag_count -eq 0 ]];then
			Node_flag=$((Node_flag-1))
			#echo $Node_flag
			echo "$tp_list node packing program Get data success."
		else
			echo "$tp_list node packing program still takes data before packing."
		fi
	done

	if [[ $Node_flag -eq 0 ]];then
		break	
	else
		sleep 2
	fi
done
#system__alarm_b=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "select sum(count) from inst_db_count;"'`

#scp -r root@$DBA_ip:/proc/net/dev $Agent_Auto_PT_home_dir/rms_info >>/dev/null  2>&1
#DBA_eth1_T_b=`cat $Agent_Auto_PT_home_dir/rms_info/dev | grep eth1 | sed 's/:/ /g' | awk '{print $10}'`
#echo $DBA_eth1_T_b
#DBA_eth2_R_b=`cat $Agent_Auto_PT_home_dir/rms_info/dev | grep eth2 | sed 's/:/ /g' | awk '{print $2}'`
#echo $DBA_eth2_R_b

##开始tcpreplay打包
#tcpreplay -M 30 -l 100 -i eth1 loadrunner.pcap >> $Agent_report
#tcpreplay -M 10 -l 1 -i eth1 loadrunner_long.pcap >> $Agent_report
#DBA_date_now_b=`ssh root@$DBA_ip "date '+%Y-%m-%d %H:%M:%S'"`
DBA_detail_max_id_b=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "select max(id) from system_cpu_mem_detail;"'`

#if [[ $tcpreplay_given -eq 0 ]];then
	nohup tcpreplay -$tcpreplay_given $tcpreplay_rate -l $tcpreplay_loop -i $tcpreplay_eth_T $pcap_name > $Agent_Auto_PT_home_dir/tcpreplay_info.txt &
#elif [[ $tcpreplay_given -eq 1 ]];then
#	nohup tcpreplay -p $tcpreplay_rate -l $tcpreplay_loop -i $tcpreplay_eth_T $Agent_Auto_PT_home_dir/$pcap_name > $Agent_Auto_PT_home_dir/tcpreplay_info.txt &
#fi

#nohup tcpreplay -i eth1  loadrunner-longsess2000.pcap > tcpreplay_info.txt &
rm -rf $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt
rmagent_pid=`ssh root@$Agent_ip "ps -ef|grep '/usr/local/rmagent/rmagent'|grep -v grep"|awk '{print $2}'`
echo $rmagent_pid
while true
do
	if [[ `ps -ef|grep -E "tcpreplay.*$pcap_name" |grep -v -E "grep|$DBA_ip"|wc -l` -ge 1 ]];then
		ssh root@$Agent_ip "top -b -n 1 -p $rmagent_pid | grep rmagent" >> $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt
		#ssh root@192.168.5.194 "top -b -n 1 -p 9840  | grep rmagent" >> ./rmagent_cpu_mem.txt
		echo "get Agent_$Agent_ip cpu and mem seccess!"
		sleep 2
	else
		#DBA_date_now_a=`ssh root@$DBA_ip "date '+%Y-%m-%d %H:%M:%S'"`
		DBA_detail_max_id_a=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "select max(id) from system_cpu_mem_detail;"'`
		tcpreplay_time=`cat $Agent_Auto_PT_home_dir/tcpreplay_info.txt |grep "Actual:"|awk '{print $8}'`
		#if [[ $tcpreplay_time -eq 0 ]];then
		#	tcpreplay_time=1
		#fi
		break
	fi	
done
		
#((tcpreplay_time=$date_now_a-$date_now_b))
#echo $tcpreplay_time >> $Agent_report
while true
do
	tlog_count=0
	t_count=`ssh root@$DBA_ip ls /dbfw_tlog|grep -E "INST_tlog_20"|wc -l`
	tlog_count=$((tlog_count+t_count))
	sleep 0.1
	t_count=`ssh root@$DBA_ip ls /dbfw_tlog|grep -E "INST_tlog_20"|wc -l`
	tlog_count=$((tlog_count+t_count))
	sleep 0.1
	t_count=`ssh root@$DBA_ip ls /dbfw_tlog|grep -E "INST_tlog_20"|wc -l`
	tlog_count=$((tlog_count+t_count))
	if [[ $tlog_count -ne 0 ]];then
		echo "tlogfile No analysis completed!"
		sleep 10
	else
		sleep 30
		break
	fi
done
#sleep $5

echo "" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "tcpreplay打包后信息" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report

if [[ $tcpreplay_kernel_version != "el7" ]];then
	tcpreplay_Tx_pck_a=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $2}'|awk -F: '{print $2}'`
	tcpreplay_T_d_pck_a=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $4}'|awk -F: '{print $2}'`
else
	tcpreplay_Tx_pck_a=`ifconfig $tcpreplay_eth_T|grep "TX packets"|awk '{print $3}'`
	tcpreplay_T_d_pck_a=`ifconfig $tcpreplay_eth_T|grep "TX errors"|awk '{print $5}'`
fi

if [[ $Agent_kernel_version != "el7" ]];then
	tcpreplay_Rx_pck_a=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $2}'|awk -F: '{print $2}'`
	tcpreplay_R_d_pck_a=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $4}'|awk -F: '{print $2}'`
else
	tcpreplay_Rx_pck_a=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX packets'"|awk '{print $3}'`
	tcpreplay_R_d_pck_a=`ssh root@$Agent_ip "ifconfig $tcpreplay_eth_R|grep 'RX errors'"|awk '{print $5}'`
fi

echo "tcpreplay发包网卡的发包数 TX packets:"$tcpreplay_Tx_pck_a >> $Agent_report
echo "tcpreplay收包网卡的收包数 RX packets:"$tcpreplay_Rx_pck_a >> $Agent_report

echo "tcpreplay发包网卡drop包数:"$tcpreplay_T_d_pck_a >> $Agent_report
echo "tcpreplay收包网卡drop包数:"$tcpreplay_R_d_pck_a >> $Agent_report

Agent_info_a="Agent_info_a_Node${Node_num}_${Agent_ip}"

mkdir $Agent_Auto_PT_home_dir/${Agent_info_a}
scp -r root@$Agent_ip:/tmp/rmagent/rmagent_info.log $Agent_Auto_PT_home_dir/${Agent_info_a} >>/dev/null  2>&1

Agent_pcap_recv_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "rmagent device report. pcap_recv"|tail -n 1|awk '{print $6}'|awk -F: '{print $2}'`
echo "Agent日志中pcap_recv(网卡收到包数):"$Agent_pcap_recv_a >> $Agent_report

Agent_drop_recv_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "rmagent device report. pcap_recv"|tail -n 1|awk '{print $7}'|awk -F: '{print $2}'`
echo "Agent日志中pcap_drop(网卡丢包数):"$Agent_drop_recv_a >> $Agent_report

Agent_w_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "w_count  ="|grep -v "buf"|tail -n1|awk '{print $5}'`
echo "Agent日志中w_count(缓冲区写包数):"$Agent_w_count_a >> $Agent_report

Agent_r_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "w_count  ="|grep -v "buf"|tail -n1|awk '{print $8}'`
echo "r_count (缓冲区读包数/即发包数):"$Agent_r_count_a >> $Agent_report

Agent_w_full_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "w_full_count ="|tail -n1|awk '{print $5}'`
echo "Agent日志中w_full_count(缓冲区写满次数):"$Agent_w_full_count_a >> $Agent_report

Agent_buf0_w_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "buf\[0\] w_count"|tail -n1|awk '{print $6}'`
echo "Agent日志中buf[0] w_count(缓冲区数据包数):"$Agent_buf0_w_count_a >> $Agent_report

Agent_buf0_r_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "buf\[0\] w_count"|tail -n1|awk '{print $9}'`
echo "Agent日志中buf[0] r_count(数据包发包数):"$Agent_buf0_r_count_a >> $Agent_report

Agent_buf1_w_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "buf\[1\] w_count"|tail -n1|awk '{print $6}'`
echo "Agent日志中buf[1] w_count(缓冲区控制包数):"$Agent_buf1_w_count_a >> $Agent_report

Agent_buf1_r_count_a=`tail -n 100 $Agent_Auto_PT_home_dir/${Agent_info_a}/rmagent_info.log|grep "buf\[1\] w_count"|tail -n1|awk '{print $9}'`
echo "Agent日志中buf[1] r_count(控制包发包数):"$Agent_buf1_r_count_a >> $Agent_report

#cat $Agent_report

rms_info_a="rms_info_a_Node${Node_num}_${DBA_ip}"

scp -r root@$DBA_ip:/dbfw_capbuf/pdump/rms/runtime/ $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1

rms_info_filename=`ls -l $Agent_Auto_PT_home_dir/${rms_info_a}|tail -n1|awk '{print $9}'`

if [[ $rms_info_filename =~ "." ]];then
        rms_info_filename=${rms_info_filename%.*}
fi

#echo $rms_info_filename

rms_check_count_a=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_a}/$rms_info_filename |grep "check_count ="|tail -n1|awk '{print $3}'`
echo "rms日志check_count(收到总包数):"$rms_check_count_a >> $Agent_report

rms_ctl_count_a=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_a}/$rms_info_filename |grep "check_count ="|tail -n1|awk '{print $6}'`
echo "rms日志ctl_count(控制包数):"$rms_ctl_count_a >> $Agent_report

rms_send_count_a=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_a}/$rms_info_filename |grep "send_count ="|tail -n1|awk '{print $3}'`
echo "rms日志send_count(发送总包数):"$rms_send_count_a >> $Agent_report

rms_send_failed_count_a=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_a}/$rms_info_filename |grep "send_failed_count ="|tail -n1|awk '{print $6}'`
echo "rms日志send_failed_count(发送失败包数):"$rms_send_failed_count_a >> $Agent_report

rms_fifo_in_failed_count_a=`tail -n100 $Agent_Auto_PT_home_dir/${rms_info_a}/$rms_info_filename |grep "fifo_in_failed_count ="|tail -n1|awk '{print $3}'`
echo "rms日志fifo_in_failed_count(写失败次数):"$rms_fifo_in_failed_count_a >> $Agent_report

DBA_eth1_T_a=`ssh root@$DBA_ip ifconfig eth1|grep "TX packets"|awk '{print $2}'|awk -F: '{print $2}'`
echo "DBA侧eth1网卡TX packets:"$DBA_eth1_T_a >> $Agent_report

if [ $DBA_RUN_PROCESS_MODE -eq 0 -o $DBA_RUN_PROCESS_MODE -eq 2 ];then

	if [[ $DBA_kernel_version != "el7" ]];then
		DBA_eth1_T_a=`ssh root@$DBA_ip ifconfig eth1|grep "TX packets"|awk '{print $2}'|awk -F: '{print $2}'`
	else
		DBA_eth1_T_a=`ssh root@$DBA_ip ifconfig eth1|grep "TX packets"|awk '{print $3}'`
	fi

        echo "DBA侧eth1网卡TX packets:"$DBA_eth1_T_a >> $Agent_report

        if [[ $DBA_RUN_PROCESS_MODE -eq 0 ]];then

		if [[ $DBA_kernel_version != "el7" ]];then
			DBA_eth2_R_a=`ssh root@$DBA_ip ifconfig eth2|grep "RX packets"|awk '{print $2}'|awk -F: '{print $2}'`
		else
			DBA_eth2_R_a=`ssh root@$DBA_ip ifconfig eth2|grep "RX packets"|awk '{print $3}'`
		fi

                echo "DBA侧eth2网卡RX packets:"$DBA_eth2_R_a >> $Agent_report
                scp -r root@$DBA_ip:/dev/shm/npc/npc_packet_stats $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1
                npc_rx_pkt_tot_a=`cat $Agent_Auto_PT_home_dir/${rms_info_a}/npc_packet_stats|awk '/rx_pkt_tot/{print $3}'`
                echo "npc状态文件标记处理包数:"$npc_rx_pkt_tot_a >> $Agent_report
	elif [[ $DBA_RUN_PROCESS_MODE -eq 2 ]];then
		scp -r root@$DBA_ip:/dev/shm/dpdk/dpdk_nic_stats $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1
		scp -r root@$DBA_ip:/tmp/dpdk/eth_pci_map $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1
		eth_R_flag=`cat $Agent_Auto_PT_home_dir/${rms_info_a}/eth_pci_map|grep "${rms_eth_R}" |awk -F = '{print $2}'`
		echo "Get eth_R_flag(after tcpreplay):$eth_R_flag Seccess!"
		str_row=`grep -n "$eth_R_flag" $Agent_Auto_PT_home_dir/${rms_info_a}/dpdk_nic_stats|cut -d ':' -f 1`
		str_row=$((str_row+2))
		echo "Get dpdk_nic_stats(after tcpreplay) date str_row:$str_row Seccess!"
                nfw_rx_pkt_tot_a=`sed -n "${str_row}p" $Agent_Auto_PT_home_dir/${rms_info_a}/dpdk_nic_stats |awk '{print $3}'`
                echo "nfw状态文件标记处理包数:"$nfw_rx_pkt_tot_a >> $Agent_report
        fi
elif [[ $DBA_RUN_PROCESS_MODE -eq 1 ]];then
        scp -r root@$DBA_ip:/dev/shm/rms/rms_packet_stats $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1
        rms_rx_pkt_tot_a=`cat $Agent_Auto_PT_home_dir/${rms_info_a}/rms_packet_stats|awk '/rx_pkt_tot/{print $3}'`
        echo "rms状态文件标记处理包数:"$rms_rx_pkt_tot_a >> $Agent_report
fi

scp -r root@$DBA_ip:/dev/shm/rmagent/rmagent_stat_${Agent_client_ip}* $Agent_Auto_PT_home_dir/${rms_info_a} >>/dev/null  2>&1
rmagent_stat_filename=`ls $Agent_Auto_PT_home_dir/${rms_info_a}/rmagent_stat_${Agent_client_ip}*`
#Agent_send_packet_count_a=`cat $Agent_Auto_PT_home_dir/${rms_info_a}/rmagent_stat_${Agent_client_ip}|awk -F: '/\[send_packet_count\]/{print $2}'`
Agent_send_packet_count_a=`cat $rmagent_stat_filename|awk -F: '/\[send_packet_count\]/{print $2}'`
echo "Agent_${Agent_client_ip}状态文件标记send包数:"$Agent_send_packet_count_a >> $Agent_report

sql_count_a=`ssh root@$DBA_ip '/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e "select sum(count) from inst_db_count;"'`

echo "打包后sql数:"$sql_count_a >> $Agent_report

echo "" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "系统信息" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report

echo "" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "tcpreplay执行日志" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "" >> $Agent_report
echo "打包命令及参数:tcpreplay -p $tcpreplay_rate -l $tcpreplay_loop -i $tcpreplay_eth_T $pcap_name" >> $Agent_report
echo "" >> $Agent_report
cat $Agent_Auto_PT_home_dir/tcpreplay_info.txt >> $Agent_report
rm -rf $Agent_Auto_PT_home_dir/tcpreplay_info.txt

echo "" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "打包过程网卡,日志前后包数差值,审计语句数,rmagent占cup\mem百分比" >> $Agent_report
echo "--------------------------------------------------------------------------------" >> $Agent_report
echo "tcpreplay发包网卡的发包数TX packets: "$((tcpreplay_Tx_pck_a-tcpreplay_Tx_pck_b)) >> $Agent_report
echo "tcpreplay发包网卡本次打包drop packets: "$((tcpreplay_T_d_pck_a-tcpreplay_T_d_pck_b)) >> $Agent_report
echo "tcpreplay收包网卡的收包数RX packets: "$((tcpreplay_Rx_pck_a-tcpreplay_Rx_pck_b)) >> $Agent_report
echo "tcpreplay收包网卡本次打包drop packets: "$((tcpreplay_R_d_pck_a-tcpreplay_R_d_pck_b)) >> $Agent_report
echo "Agent日志中pcap_recv(收到包数): "$((Agent_pcap_recv_a-Agent_pcap_recv_b)) >> $Agent_report
echo "Agent日志中pcap_drop(丢包数): "$((Agent_drop_recv_a-Agent_drop_recv_b)) >> $Agent_report
if [[ $((Agent_drop_recv_a-Agent_drop_recv_b)) -ne 0 ]];then
	pcap_drop_percentage=`echo "$Agent_drop_recv_a $Agent_drop_recv_b $Agent_pcap_recv_a $Agent_pcap_recv_b"|awk '{printf ("%0.5f\n",($1-$2)*100/($3-$4))}'`
	echo "Agent日志中pcap_drop(丢包百分比) :"$pcap_drop_percentage >> $Agent_report
fi
echo "Agent日志中w_count(缓冲区写包数): "$((Agent_w_count_a-Agent_w_count_b)) >> $Agent_report
echo "r_count(缓冲区读包数/即发包数): "$((Agent_r_count_a-Agent_r_count_b)) >> $Agent_report
echo "Agent日志中w_full_count(缓冲区写满次数):"$((Agent_w_full_count_a-Agent_w_full_count_b)) >> $Agent_report
echo "Agent日志中buf[0] w_count(缓冲区数据包数): "$((Agent_buf0_w_count_a-Agent_buf0_w_count_b)) >> $Agent_report
echo "Agent日志中buf[0] r_count(数据包发包数): "$((Agent_buf0_r_count_a-Agent_buf0_r_count_b)) >> $Agent_report
echo "Agent日志中buf[1] w_count(缓冲区控制包数): "$((Agent_buf1_w_count_a-Agent_buf1_w_count_b)) >> $Agent_report
echo "Agent日志中buf[1] r_count(控制包发包数): "$((Agent_buf1_r_count_a-Agent_buf1_r_count_b)) >> $Agent_report
echo "rms日志check_count(收到总包数): "$((rms_check_count_a-rms_check_count_b)) >> $Agent_report
echo "rms日志ctl_count(控制包数): "$((rms_ctl_count_a-rms_ctl_count_b)) >> $Agent_report
echo "rms日志send_count(发送总包数): "$((rms_send_count_a-rms_send_count_b)) >> $Agent_report
echo "rms日志send_failed_count(发送失败包数): "$((rms_send_failed_count_a-rms_send_failed_count_b)) >> $Agent_report
echo "rms日志fifo_in_failed_count(写失败次数): "$((rms_fifo_in_failed_count_a-rms_fifo_in_failed_count_a)) >> $Agent_report

if [ $DBA_RUN_PROCESS_MODE -eq 0 -o $DBA_RUN_PROCESS_MODE -eq 2 ];then
	echo "DBA侧eth1网卡TX packets: "$((DBA_eth1_T_a-DBA_eth1_T_b)) >> $Agent_report
        if [[ $DBA_RUN_PROCESS_MODE -eq 0 ]];then
		echo "DBA侧eth2网卡RX packets: "$((DBA_eth2_R_a-DBA_eth2_R_b)) >> $Agent_report
		echo "npc状态文件标记处理包数: "$((npc_rx_pkt_tot_a-npc_rx_pkt_tot_b)) >> $Agent_report
	elif [[ $DBA_RUN_PROCESS_MODE -eq 2 ]];then
		echo "nfw状态文件标记处理包数: "$((nfw_rx_pkt_tot_a-nfw_rx_pkt_tot_b)) >> $Agent_report
        fi
elif [[ $DBA_RUN_PROCESS_MODE -eq 1 ]];then
	echo "rms状态文件标记处理包数: "$((rms_rx_pkt_tot_a-rms_rx_pkt_tot_b)) >> $Agent_report
fi

echo "Agent_${Agent_client_ip}状态文件标记send包数: "$(($Agent_send_packet_count_a-$Agent_send_packet_count_b)) >> $Agent_report

#sql_e=$((expect_sql*tcpreplay_loop*Node_count))
sql_e=$((expect_sql*tcpreplay_loop))
echo "打包过程预期sql数: "$sql_e >> $Agent_report
sql_f=$((sql_count_a-sql_count_b))
echo "打包过程审计sql数: "$sql_f >> $Agent_report
echo "打包过程漏审sql数: "$((sql_e-sql_f)) >> $Agent_report
sql_lose_percentage=`echo "$sql_e $sql_f $sql_e"|awk '{printf ("%0.5f\n",($1-$2)*100/$3)}'`
echo "打包过程漏审sql百分比: "$sql_lose_percentage >> $Agent_report
((sql_count=$sql_count_a-$sql_count_b))
#((sql_s=$sql_count/$tcpreplay_time))

sql_s=`echo "$sql_count $tcpreplay_time" | awk '{print int($1/$2)}'`

echo "打包过程每秒sql数: "$sql_s >> $Agent_report
rmagent_cpu_avg=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk '{sum+=$9} END {printf "Average: %.1f\n", sum/NR}'`
echo "打包过程中rmagent占cpu一个核的百分比(均值)"$rmagent_cpu_avg >> $Agent_report
rmagent_cpu_max=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk 'BEGIN {max = 0} {if ($9+0>max+0) max=$9 fi} END {print "Max: ", max}'`
echo "打包过程中rmagent占cpu一个核的百分比(峰值)"$rmagent_cpu_max >> $Agent_report
rmagent_cpu_mix=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk 'BEGIN {mix = 1000} {if ($9+0<mix+0) mix=$9 fi} END {print "Mix: ", mix}'`
echo "打包过程中rmagent占cpu一个核的百分比(谷值)"$rmagent_cpu_mix >> $Agent_report
rmagent_mem_avg=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk '{sum+=$10} END {printf "Average: %.1f\n ", sum/NR}'`
echo "打包过程中rmagent占内存百分比(均值)"$rmagent_mem_avg >> $Agent_report
rmagent_mem_max=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk 'BEGIN {max = 0} {if ($10+0>max+0) max=$10 fi} END {print "Max: ", max}'`
echo "打包过程中rmagent占内存百分比(峰值)"$rmagent_mem_max >> $Agent_report
rmagent_mem_mix=`cat $Agent_Auto_PT_home_dir/rmagent_cpu_mem.txt|awk 'BEGIN {mix = 1000} {if ($10+0<mix+0) mix=$10 fi} END {print "Mix: ", mix}'`
echo "打包过程中rmagent占内存百分比(谷值)"$rmagent_mem_mix >> $Agent_report

DBA_cup_mem_sql="SELECT id,mem,cpu,cpu_usr,cpu_sys,cpu_iowait,logtime FROM system_cpu_mem_detail where id>=$DBA_detail_max_id_b and id<=$DBA_detail_max_id_a"
echo $DBA_cup_mem_sql
ssh root@$DBA_ip "/home/dbfw/dbfw/DBCDataCenter/bin/DBCDataView -P9207 -h127.0.0.1 -uroot -p1 dbfw -N -e '$DBA_cup_mem_sql'" > $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt

DBA_cpu_avg=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk '{sum+=$3} END {printf "verage: %.1f\n", sum/NR}'`
echo "打包过程中DBA cpu使用百分比(均值)"$DBA_cpu_avg >> $Agent_report
DBA_cpu_max=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk 'BEGIN {max = 0} {if ($3+0>max+0) max=$3 fi} END {print "Max: ", max}'`
echo "打包过程中DBA cpu使用百分比(峰值)"$DBA_cpu_max >> $Agent_report
DBA_cpu_mix=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk 'BEGIN {mix = 1000} {if ($3+0<mix+0) mix=$3 fi} END {print "Mix: ", mix}'`
echo "打包过程中DBA cpu使用百分比(谷值)"$DBA_cpu_mix >> $Agent_report
DBA_mem_avg=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk '{sum+=$2} END {printf "Average: %.1f\n", sum/NR}'`
echo "打包过程中DBA 内存使用百分比(均值)"$DBA_mem_avg >> $Agent_report
DBA_mem_max=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk 'BEGIN {max = 0} {if ($2+0>max+0) max=$2 fi} END {print "Max: ", max}'`
echo "打包过程中DBA 内存使用百分比(峰值)"$DBA_mem_max >> $Agent_report
DBA_mem_mix=`cat $Agent_Auto_PT_home_dir/DBA_cpu_mem.txt|awk 'BEGIN {mix = 1000} {if ($2+0<mix+0) mix=$2 fi} END {print "Mix: ", mix}'`
echo "打包过程中DBA 内存使用百分比(谷值)"$DBA_mem_mix >> $Agent_report

rm -rf /tmp/Node${Node_num}_${tcpreplay_ip} >> $Agent_report
cat $Agent_report
