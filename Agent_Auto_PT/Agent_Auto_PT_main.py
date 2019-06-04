#!/usr/bin/python
#_*_coding: UTF-8_*_
###################################
## auther:liuguanghui
## date:20181116
## work:Agent performance testing
###################################
import sys
import os
import ConfigParser
import time
import datetime
import socket
import fcntl
import struct
from collections import OrderedDict

def GetCwdPath():
        return os.path.split(os.path.realpath(sys.argv[0]))[0]

def config_value(key_name):
	kvs = config.items(key_name)
	result=[]
	for key,value in kvs:
		result.append(value)
	return result

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])


#tmp_Node_count = 0

nowTime=datetime.datetime.now().strftime('%Y%m%d%H%M%S')

Agent_Auto_PT_master_dir = GetCwdPath()

localhost_ip = get_ip_address('eth0')
##config = ConfigParser.ConfigParser()
##定此方法的字典类型
config = ConfigParser.ConfigParser(dict_type=OrderedDict)
config.read("%s/Agent_Auto_PT.ini"%Agent_Auto_PT_master_dir)

##Agent_Auto_Pt.ini中[Public]中所有参数列表
Public_param_list = config_value("Public")
##Agent_Auto_Pt.ini中[Public]中所有参数列表中需要传入Agent_Auto_PT.sh中的字符串化
Public_param_str = ' '.join(Public_param_list[0:10])
print Public_param_str

#打包节点数
Node_count = int(Public_param_list[10])

Node_num = 0
for num in range(0,Node_count):
        Node_param_list = config_value("Node%d"%(num + 1))
        Node_param_str = ' '.join(Node_param_list)
        
        Node_num = Node_num + 1
        print Node_num
        tcpreplay_ip = config.get('Node%d'%(Node_num), 'tcpreplay_ip')
        rs = os.system('ssh root@%s "rm -rf /tmp/Node*;rm -rf /tmp/PT_flag_*"'%(tcpreplay_ip))
	if rs != 0:
		print "Node%s_%s 没有设置ssh免密码登录,程序退出!"%(Node_num,tcpreplay_ip)
		exit()


Node_num = 0
for num in range(0,Node_count):
	Node_param_list = config_value("Node%d"%(num + 1))
	Node_param_str = ' '.join(Node_param_list)
	
	Node_num = Node_num + 1
	print Node_num
	tcpreplay_ip = config.get('Node%d'%(Node_num), 'tcpreplay_ip')
	Agent_Auto_PT_home_dir = config.get('Node%d'%(Node_num), 'Agent_Auto_PT_home_dir')
	os.system('scp %s/Agent_Auto_PT.ini Agent_Auto_PT.sh Agent_Auto_PT_main.py root@%s:%s/'\
%(Agent_Auto_PT_master_dir,tcpreplay_ip,Agent_Auto_PT_home_dir))
	os.system('ssh root@%s "nohup %s/Agent_Auto_PT.sh %s %s %s %s %s >> %s/Agent_Auto_PT_%s.log &"'\
%(tcpreplay_ip,Agent_Auto_PT_home_dir,Public_param_str,Node_param_str,Node_count,Node_num,nowTime,Agent_Auto_PT_home_dir,tcpreplay_ip))
	os.system('ssh root@%s touch /tmp/Node%s_%s'%(tcpreplay_ip,Node_num,tcpreplay_ip))
	print 'Node%s_%s 开始运行'%(Node_num,tcpreplay_ip)

	print 'ssh root@%s "nohup %s/Agent_Auto_PT.sh %s %s %s %s %s >> %s/Agent_Auto_PT_%s.log &"'\
%(tcpreplay_ip,Agent_Auto_PT_home_dir,Public_param_str,Node_param_str,Node_count,Node_num,nowTime,Agent_Auto_PT_home_dir,tcpreplay_ip)

tcpreplay_given = config.get('Public', 'tcpreplay_given')
tcpreplay_rate = config.get('Public', 'tcpreplay_rate')
tcpreplay_loop = config.get('Public', 'tcpreplay_loop')
expect_sql = config.get('Public', 'expect_sql')

if not os.path.isdir('%s/Agent_report_Summary_histry'%Agent_Auto_PT_master_dir):
	os.makedirs('%s/Agent_report_Summary_histry'%Agent_Auto_PT_master_dir)

os.system('mv %s/Agent_report_Summary_20* %s/Agent_report_Summary_histry/'%(Agent_Auto_PT_master_dir,Agent_Auto_PT_master_dir))

Summary_dir = "%s/Agent_report_Summary_%s"%(Agent_Auto_PT_master_dir,nowTime)

os.system('mkdir %s'%Summary_dir)

os.system('\cp %s/Agent_Auto_PT.ini %s/'%(Agent_Auto_PT_master_dir,Summary_dir))

Node_num = 0
while 1:
	print "----------------------------------------------------"
	for num in range(0,Node_count):
		Node_num=num + 1
		tcpreplay_ip = config.get('Node%d'%(Node_num), 'tcpreplay_ip')
		Agent_ip = config.get('Node%d'%(Node_num), 'Agent_ip')
		Agent_Auto_PT_home_dir = config.get('Node%d'%(Node_num), 'Agent_Auto_PT_home_dir')
		rs = os.system('ssh root@%s ls /tmp/Node%s_%s >/dev/null 2>&1'%(tcpreplay_ip,Node_num,tcpreplay_ip))
		if rs != 0:
			print 'Node%s_%s 运行结束'%(Node_num,tcpreplay_ip)
			os.system('scp root@%s:%s/Agent_report_%s_%s_Node%s_%s-%s_l-%s_esql%s.txt %s/Agent_report_%s_%s_Node%s_%s-%s_l-%s_esql%s.txt'\
%(tcpreplay_ip,Agent_Auto_PT_home_dir,nowTime,Agent_ip,Node_num,tcpreplay_given,tcpreplay_rate,tcpreplay_loop,expect_sql,\
Summary_dir,nowTime,Agent_ip,Node_num,tcpreplay_given,tcpreplay_rate,tcpreplay_loop,expect_sql))
			print 'Get Node%s_%s report文件成功!'%(Node_num,tcpreplay_ip)
			os.system('scp -r root@%s:%s/{Agent_info*,rms_info*} %s/'%(tcpreplay_ip,Agent_Auto_PT_home_dir,Summary_dir))
			print "Node%s_%s 打包前后rmagent rms日志文件成功!"%(Node_num,tcpreplay_ip)
			Node_count = Node_count - 1
		else:
			print 'Node%s_%s 运行中...'%(Node_num,tcpreplay_ip)
			time.sleep(5)
	if Node_count == 0:
		print "所有打包节点打包、统计完成"	
		break
