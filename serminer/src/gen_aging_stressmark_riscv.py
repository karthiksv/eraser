# Copyright 2020 IBM Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import sys
import csv
import numpy as np
import string
import random
import os
import os.path
import subprocess as sp
from collections import defaultdict
import pdb 
from numpy import genfromtxt
#np.set_printoptions(threshold=np.nan)

VERBOSE=0
INST_SCALE_FACTOR = 1
WTED_SW_THRESHOLD = 1e-4 #Stop adding instructions when remaining switching is less than this value

def get_cov_dict_info(infile, ind_array, ninsts):
    cov_dict = defaultdict(list)
    pruned_dict = defaultdict(list)
    selected_dict = defaultdict(list)
    macro_list = np.zeros(ninsts)

    with open(infile) as cf:
        header = cf.readline()	#Skip 1st line
        for line in cf:
            dict_arr = line.split()
            cov_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(int)
            pruned_dict[dict_arr[0]] = cov_dict[dict_arr[0]]
            selected_dict[dict_arr[0]] = np.zeros(ninsts)
            selected_dict[dict_arr[0]][ind_array.astype(int)] = np.array(dict_arr)[1+ind_array.astype(int)].astype(float)
            selected_sum = np.sum(selected_dict[dict_arr[0]])
            macro_list = macro_list + selected_dict[dict_arr[0]]
            if (selected_sum==0):
                del pruned_dict[dict_arr[0]]
            #else:
                #print(str(dict_arr[0]) + " : " +str(cov_sum))
    return pruned_dict, macro_list

def get_wm_info(wm_file):
    wm_dict = defaultdict(list)
    with open(wm_file) as wm:
        for line in wm:
            dict_arr = line.split()
            wm_dict[dict_arr[0]] = np.array(dict_arr[1]).astype(float)
    return wm_dict
    
    
def get_sw_dict_info(infile, ind_array, m_wt, ninsts):
    sw_dict = defaultdict(list)
    wted_sw_dict = defaultdict(list)
    pruned_dict = defaultdict(list)
    pruned_wted_dict = defaultdict(list)
    selected_dict = defaultdict(list)
    selected_wted_dict = defaultdict(list)
    macro_list = np.zeros(ninsts)
    macro_wted_list = np.zeros(ninsts)
    norm_macro_wted_list = np.zeros(ninsts) 

    with open(infile) as sf:
        header = sf.readline()	#Skip 1st line
        for line in sf:
            dict_arr = line.split()
            sw_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(float)
            selected_dict[dict_arr[0]] = np.zeros(ninsts)
            selected_dict[dict_arr[0]][ind_array.astype(int)] = np.array(dict_arr)[1+ind_array.astype(int)].astype(float)
            pruned_dict[dict_arr[0]] = selected_dict[dict_arr[0]]
            wted_sw_dict[dict_arr[0]] = m_wt[dict_arr[0]]*selected_dict[dict_arr[0]]
            pruned_wted_dict[dict_arr[0]] = wted_sw_dict[dict_arr[0]]
            sw_sum = np.sum(sw_dict[dict_arr[0]])
            selected_sum = np.sum(selected_dict[dict_arr[0]])
            macro_list = macro_list + selected_dict[dict_arr[0]]
            macro_wted_list = macro_wted_list + m_wt[dict_arr[0]]*selected_dict[dict_arr[0]]
            max_selected_val = float(np.max(np.array(selected_dict[dict_arr[0]])))
            if (max_selected_val > 0):
                norm_macro_wted_list = norm_macro_wted_list + (m_wt[dict_arr[0]]/max_selected_val)*selected_dict[dict_arr[0]]
            max_wted_val = np.max(np.array(norm_macro_wted_list))
            if (selected_sum==0):
                if (VERBOSE==1):
                    print("Deleting "+str(dict_arr[0]))
                    print ("Max weighted switching: "+str(max_wted_val))
                del pruned_dict[dict_arr[0]]
                del pruned_wted_dict[dict_arr[0]]
    return pruned_dict, macro_list, macro_wted_list
    
def get_res_dict_info(res_file, ninsts):
    res_dict = defaultdict(list)
    pruned_dict = defaultdict(list)
    macro_list = np.zeros(ninsts)
    with open(res_file) as rf:
        header = rf.readline()	#Skip 1st line
        for line in rf:
            dict_arr = line.split()
            #res_dict[dict_arr[0]] = (np.array(dict_arr)[1+selected_indices.astype(int)]).astype(float)
            res_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(float)
            pruned_dict[dict_arr[0]] = res_dict[dict_arr[0]]
            res_sum= np.sum(res_dict[dict_arr[0]])
            macro_list = macro_list + res_dict[dict_arr[0]]

            if (res_sum==0):
                del pruned_dict[dict_arr[0]]
            #else:
                #print(str(dict_arr[0]) + " : " +str(res_sum))
    return pruned_dict, macro_list


def get_targeted_dicts(cov_dict, sw_dict, macro_array):
    t_cov_dict = defaultdict(list)
    t_sw_dict = defaultdict(list)
    for m in macro_array:
       t_cov_dict[m] = cov_dict[m]
       t_sw_dict[m] = sw_dict[m]
    return t_cov_dict, t_sw_dict



def gen_random_inst_list(inst_array, frac):
    #ifile=open(inst_file);
    #all_insts = [x.strip() for x in ifile.readlines()]
    num_lines = len(inst_array)
    selected_inst_indices = np.array(np.sort(random.sample(range(1,num_lines),int(frac*num_lines))))
    selected_inst_array = np.array(inst_array)[selected_inst_indices.astype(int)]
    #print(num_lines,frac,selected_inst_array)
    return selected_inst_array, selected_inst_indices
           
def get_stressmark_inst_res(cov_list, res_list, inst_index, tot_cov_list, tot_res_list, return_list):
    #pdb.set_trace()
    #find max residency value
    max_res = max(tot_res_list.values())
    #if VERBOSE:
    #	print(tot_sw_list.values())
    #Find list of instructions with max residency
    max_res_list = [inst for inst,val in tot_res_list.items() if val==max_res]

    #Check which insts with max residency have highest coverwge - use 1st inst in case of tie
    max_cov = max([tot_cov_list[inst] for inst in max_res_list])
    tmp_list=dict(zip(max_res_list,[tot_cov_list[inst] for inst in max_res_list]))
    #max_cov_list = [inst for inst,val in tot_cov_list.items() if val==max_cov]
    max_cov_list = [inst for inst,val in tmp_list.items() if val==max_cov]

    #Choose instruction with max coverage in case of tie.. if coverage is equal, choose a random index
    random_cov_index=random.randint(0,len(max_cov_list)-1)  
    if VERBOSE: 
        print(max_res, max_res_list)
        print("Coverage of max insts: ")
        print(max_cov,max_cov_list[random_cov_index],inst_index[max_cov_list[random_cov_index]])
        print("Selected index = "+str(random_cov_index)+ " length: " +str(len(max_cov_list)))
    
    todel_list=[]
    deleted_cov_list=[]
    deleted_res_list=[]
    deleted_list_count = 0
	
    for macro in res_list:
        if (res_list[macro][inst_index[max_cov_list[random_cov_index]]] > 0):
            todel_list.append(macro)    
    
    if VERBOSE: 
        print("macros to delete")
        print(todel_list, len(todel_list))

    #delete macros corresponding to max inst
    if len(res_list.keys()) >0 and len(todel_list)>0:
        for m in todel_list:
            deleted_res_list.append(res_list[m])
            deleted_cov_list.append(cov_list[m])
            deleted_list_count = deleted_list_count + 1
            del cov_list[m]
            del res_list[m]

        if VERBOSE: 
            print("remaining macros: " +str(len(res_list.keys())))
            print("append inst: " +str(max_cov_list[random_cov_index]))
        #append instruction to stressmark list
        return_list.append(max_cov_list[random_cov_index])
        print(return_list)
        
    else:
        if VERBOSE: 
           print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    for i in tot_res_list:
        for l in range(0,deleted_list_count): 
            if tot_res_list[i]:
                tot_res_list[i] = tot_res_list[i] - deleted_res_list[l][inst_index[i]]        
                tot_cov_list[i] = tot_cov_list[i] - deleted_cov_list[l][inst_index[i]]        
            
    #delete instruction    
    #for i in max_res_list:
    inst=max_cov_list[random_cov_index]
    del inst_index[inst]
    del tot_cov_list[inst]
    del tot_res_list[inst]

    if (len(res_list.keys()) >0):
        get_stressmark_inst_res(cov_list, res_list, inst_index, tot_cov_list, tot_res_list, return_list)
    else:    
        print(return_list)
    #return return_list

def get_stressmark_inst_sw(cov_list, sw_list, inst_index, tot_cov_list, tot_sw_list, return_list):
    #pdb.set_trace()
    #find max switching value
    max_sw = max(tot_sw_list.values())
    #Find list of instructions with max switching
    max_sw_list = [inst for inst,val in tot_sw_list.items() if val==max_sw]

    #Check which insts with max switching have highest coverwge - use 1st inst in case of tie
    max_cov = max([tot_cov_list[inst] for inst in max_sw_list])
    tmp_list = dict(zip(max_sw_list,[tot_cov_list[inst] for inst in max_sw_list]))
    #max_cov_list = [inst for inst,val in tot_cov_list.items() if val==max_cov]
    max_cov_list = [inst for inst,val in tmp_list.items() if val==max_cov]

    #Choose instruction with max coverage in case of tie.. if coverage is equal, choose a random index
    random_cov_index=random.randint(0,len(max_cov_list)-1)  

    if VERBOSE: 
        print(max_sw, max_sw_list)
        print("Coverage of max insts: ")
        print(max_cov,max_cov_list[random_cov_index],inst_index[max_cov_list[random_cov_index]])
        print("random index = "+str(random_cov_index)+ " length: " +str(len(max_cov_list)))
    
    todel_list=[]
    #deleted_cov_list=[]
    #deleted_sw_list=[]
    deleted_cov_list=defaultdict(list)
    deleted_sw_list=defaultdict(list)
    deleted_list_count = 0
	
    for macro in sw_list:
        if (sw_list[macro][inst_index[max_cov_list[random_cov_index]]] > 0):
            todel_list.append(macro)    
    
    if VERBOSE: 
        print("macros to delete")
        print(todel_list, len(todel_list))

    #delete macros corresponding to max inst
    #if len(sw_list.keys()) >0 and len(todel_list)>0:
    #    for m in todel_list:
    #        deleted_sw_list.append(sw_list[m])
    #        deleted_cov_list.append(cov_list[m])
    #        deleted_list_count = deleted_list_count + 1
    #        del cov_list[m]
    #        del sw_list[m]

    #    if VERBOSE: 
    #        print("remaining macros: " +str(len(sw_list.keys())))
    #        print("append inst: " +str(max_cov_list[random_cov_index]))

    #    #append instruction to stressmark list
    #    return_list.append(max_cov_list[random_cov_index])
    #    print(return_list)
    #else:
    #    if VERBOSE: 
    #       print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    if len(sw_list.keys()) >0 and len(todel_list)>0:
        for m in todel_list:
            deleted_sw_list[m] = sw_list[m]
            deleted_cov_list[m] = cov_list[m]
            deleted_list_count = deleted_list_count + 1
            del cov_list[m]
            del sw_list[m]

        if VERBOSE: 
            print("remaining macros: " +str(len(sw_list.keys())))
            print(sw_list.keys())
            print("append inst: " +str(max_cov_list[random_cov_index]))

        #append instruction to stressmark list
        if(len(todel_list)>0):
            return_list.append(max_cov_list[random_cov_index])
        else:
            print("No new macros selected")
        print(return_list)
    else:
        if VERBOSE: 
           print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    if VERBOSE: 
        print("Deleted KEYS and VALS::::")
        print ("COV:")
        for k,v in deleted_cov_list.items():
            print (k)
        print ("SW:")
        for k,v in deleted_sw_list.items():
            print (k)

    for i in tot_sw_list:
        #for l in range(0,deleted_list_count): 
        for l in todel_list: 
            if tot_cov_list[i]:
                #print("Sw: ",tot_sw_list[i], deleted_sw_list[l], l, i, inst_index[i])
                tot_sw_list[i] = tot_sw_list[i] - deleted_sw_list[l][inst_index[i]]
                tot_cov_list[i] = tot_cov_list[i] - deleted_cov_list[l][inst_index[i]]        
            
    #delete instruction    
    #for i in max_sw_list:
    inst=max_cov_list[random_cov_index]
    del inst_index[inst]
    del tot_cov_list[inst]
    del tot_sw_list[inst]

    #print(sw_list)
       
    if len(sw_list.keys()) >0 or len(cov_list.keys())>0:
        get_stressmark_inst_sw(cov_list, sw_list, inst_index, tot_cov_list, tot_sw_list, return_list)
    else:    
        print(return_list)
    #return return_list

def get_stressmark_inst_macro_virus(cov_list, sw_list, targeted_cov_list, targeted_sw_list, inst_index, tot_cov_list, tot_sw_list, wt_list, return_list):
    #pdb.set_trace()
    #find max switching value
    max_sw = max(tot_sw_list.values())
    #Find list of instructions with max switching
    max_sw_list = [inst for inst,val in tot_sw_list.items() if val==max_sw]

    #Check which insts with max switching have highest coverwge - use 1st inst in case of tie
    max_cov = max([tot_cov_list[inst] for inst in max_sw_list])
    tmp_list = dict(zip(max_sw_list,[tot_cov_list[inst] for inst in max_sw_list]))
    #max_cov_list = [inst for inst,val in tot_cov_list.items() if val==max_cov]
    max_cov_list = [inst for inst,val in tmp_list.items() if val==max_cov]

    #Choose instruction with max coverage in case of tie.. if coverage is equal, choose a random index
    random_cov_index=random.randint(0,len(max_cov_list)-1)  

    if VERBOSE: 
        print(max_sw, max_sw_list)
        print("Coverage of max insts: ")
        print(max_cov,max_cov_list[random_cov_index],inst_index[max_cov_list[random_cov_index]])
        print("random index = "+str(random_cov_index)+ " length: " +str(len(max_cov_list)))
    
    todel_list=[]
    #deleted_cov_list=[]
    #deleted_sw_list=[]
    deleted_cov_list=defaultdict(list)
    deleted_sw_list=defaultdict(list)
    deleted_list_count = 0
	
    for macro in sw_list:
        if (sw_list[macro][inst_index[max_cov_list[random_cov_index]]] > 0):
            todel_list.append(macro)    
    
    if VERBOSE: 
        print("macros to delete")
        print(todel_list, len(todel_list))
        #print("Weighted list")
        #for macro in todel_list:
        #    print(str(macro), " ", wt_list[macro])

    if len(sw_list.keys()) >0 and len(todel_list)>0:
        for m in todel_list:
            deleted_sw_list[m] = sw_list[m]
            deleted_cov_list[m] = cov_list[m]
            deleted_list_count = deleted_list_count + 1
            del cov_list[m]
            del sw_list[m]
            if(m in targeted_cov_list.keys()):
                del targeted_cov_list[m]
            if(m in targeted_sw_list.keys()):
                del targeted_sw_list[m]

        if VERBOSE: 
            print("remaining macros fro targeted list: " +str(len(targeted_sw_list.keys())))
            print(targeted_sw_list.keys())
            print("append inst: " +str(max_cov_list[random_cov_index]))

        #append instruction to stressmark list
        if(len(todel_list)>0):
            return_list.append(max_cov_list[random_cov_index])
        else:
            print("No new macros selected")
        print(return_list)
    else:
        if VERBOSE: 
           print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    if VERBOSE: 
        print("Deleted KEYS and VALS::::")
        print ("COV:")
        for k,v in deleted_cov_list.items():
            print (k)
        print ("SW:")
        for k,v in deleted_sw_list.items():
            print (k)

    for i in tot_sw_list:
        #for l in range(0,deleted_list_count): 
        for l in todel_list: 
            if tot_cov_list[i]:
                #print("Sw: ",tot_sw_list[i], deleted_sw_list[l], l, i, inst_index[i])
                tot_sw_list[i] = tot_sw_list[i] - wt_list[l]*deleted_sw_list[l][inst_index[i]]
                tot_cov_list[i] = tot_cov_list[i] - deleted_cov_list[l][inst_index[i]]        
            
    #delete instruction    
    #for i in max_sw_list:
    inst=max_cov_list[random_cov_index]
    del inst_index[inst]
    del tot_cov_list[inst]
    del tot_sw_list[inst]

    #print(sw_list)
    tot_sw_val = sum([tot_sw_list[i] for i in tot_sw_list])
    if VERBOSE:
        print("Tot sw: ",tot_sw_val)
    if (len(targeted_sw_list.keys()) >0 or len(targeted_cov_list.keys())>0) and tot_sw_val>WTED_SW_THRESHOLD:
        get_stressmark_inst_macro_virus(cov_list, sw_list, targeted_cov_list, targeted_sw_list, inst_index, tot_cov_list, tot_sw_list, wt_list, return_list)
    else:    
        print(return_list)
    #return return_list

def get_stressmark_inst_wted_sw(cov_list, sw_list, inst_index, tot_cov_list, tot_sw_list, wt_list, return_list):
    #pdb.set_trace()
    #find max residency value
    max_sw = max(tot_sw_list.values())
    #Find list of instructions with max switching
    max_sw_list = [inst for inst,val in tot_sw_list.items() if val==max_sw]

    #Check which insts with max switching have highest coverwge - use 1st inst in case of tie
    max_cov = max([tot_cov_list[inst] for inst in max_sw_list])
    tmp_list = dict(zip(max_sw_list,[tot_cov_list[inst] for inst in max_sw_list]))
    #max_cov_list = [inst for inst,val in tot_cov_list.items() if val==max_cov]
    max_cov_list = [inst for inst,val in tmp_list.items() if val==max_cov]

    #Choose instruction with max coverage in case of tie.. if coverage is equal, choose a random index
    random_cov_index=random.randint(0,len(max_cov_list)-1)  

    if VERBOSE: 
        print(max_sw, max_sw_list)
        print("Coverage of max insts: ")
        print(max_cov,max_cov_list[random_cov_index],inst_index[max_cov_list[random_cov_index]])
        print("random index = "+str(random_cov_index)+ " length: " +str(len(max_cov_list)))
    
    todel_list=[]
    #deleted_cov_list=[]
    #deleted_sw_list=[]
    deleted_cov_list=defaultdict(list)
    deleted_sw_list=defaultdict(list)
    deleted_list_count = 0
	
    for macro in sw_list:
        if (sw_list[macro][inst_index[max_cov_list[random_cov_index]]] > 0):
            todel_list.append(macro)    
    
    if VERBOSE: 
        print("macros to delete")
        print(todel_list, len(todel_list))

    if len(sw_list.keys()) >0 and len(todel_list)>0:
        for m in todel_list:
            deleted_sw_list[m] = sw_list[m]
            deleted_cov_list[m] = cov_list[m]
            deleted_list_count = deleted_list_count + 1
            del cov_list[m]
            del sw_list[m]

        if VERBOSE: 
            print("remaining macros: " +str(len(sw_list.keys())))
            print(sw_list.keys())
            print("append inst: " +str(max_cov_list[random_cov_index]))

        #append instruction to stressmark list
        if(len(todel_list)>0):
            return_list.append(max_cov_list[random_cov_index])
        else:
            print("No new macros selected")
        print(return_list)
    else:
        if VERBOSE: 
           print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    if VERBOSE: 
        print("Deleted KEYS and VALS::::")
        print ("COV:")
        for k,v in deleted_cov_list.items():
            print (k)
        print ("SW:")
        for k,v in deleted_sw_list.items():
            print (k)

    for i in tot_sw_list:
        #for l in range(0,deleted_list_count): 
        for l in todel_list: 
            if tot_cov_list[i]:
                #print("Sw: ",tot_sw_list[i], deleted_sw_list[l], l, i, inst_index[i])
                tot_sw_list[i] = tot_sw_list[i] - wt_list[l]*deleted_sw_list[l][inst_index[i]]
                tot_cov_list[i] = tot_cov_list[i] - deleted_cov_list[l][inst_index[i]]        
            
    #delete instruction    
    #for i in max_sw_list:
    inst=max_cov_list[random_cov_index]
    del inst_index[inst]
    del tot_cov_list[inst]
    del tot_sw_list[inst]

    #print(sw_list)
    tot_sw_val = sum([tot_sw_list[i] for i in tot_sw_list])
    if VERBOSE:
        print("Tot sw: ",tot_sw_val)
    if (len(sw_list.keys()) >0 or len(cov_list.keys())>0) and tot_sw_val>WTED_SW_THRESHOLD:
        get_stressmark_inst_wted_sw(cov_list, sw_list, inst_index, tot_cov_list, tot_sw_list, wt_list, return_list)
    else:    
        print(return_list)
    #return return_list

def main():

    print("Running command: python " +str(sys.argv) + "............")
    #Paths
    SERMINER_CONFIG_HOME=os.environ['SERMINER_CONFIG_HOME']
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output_dir", type=str, help="Output dir", required=True)
    parser.add_argument("-n", "--num_insts", type=int, help="Number of input instructions", required=False)
    parser.add_argument("-t", "--stressmark_type", type=str, help="Type of stressmark (coverage/switching/residency based)", required=False, default="res")
    parser.add_argument("-th", "--sw_threshold", type=str, help="Switching Threshold", required=True)
    parser.add_argument("-if", "--inst_fraction", type=float, help="Instruction fraction (between 0 and 1)", required=False, default=0.99)
    parser.add_argument("-il", "--workload_inst_list", type=str, help="Workload instruction list (if instruction fraction is not provided)", default=str(SERMINER_CONFIG_HOME)+'/inst_list.txt', required=False)
    parser.add_argument("-ml", "--targeted_macro_list", type=str, help="Macro list for targeted viruses", required=False, default='/tmp/DUMMY_PATH') #Python complains if a dummy path is not given
    parser.add_argument("-p", "--print_val", type=int, help="Print insts (0) / Print weights (1)", required=True)

    args = parser.parse_args()
    OUTPUT_DIR = args.output_dir
    #NUM_INSTS = args.num_insts  

    if (args.stressmark_type):
        stressmk_type = args.stressmark_type  
    sw_threshold = args.sw_threshold
    
    if (args.print_val):
        PRINT_WEIGHTS = 1
        PRINT_INSTS = 0    
    else:
        PRINT_INSTS = 1    
        PRINT_WEIGHTS = 0    
   
    if (args.inst_fraction >=1 or args.inst_fraction <0):
        print("Invalid instruction fraction... Should be between 0 and 1")    
        exit()
    else:
        inst_fraction=args.inst_fraction
    
    inst_list = str(SERMINER_CONFIG_HOME) + '/inst_list.txt'
    NUM_INSTS = len(open(inst_list).readlines())

    if (os.path.exists(args.targeted_macro_list)):		#Only if workload inst list does not exist
        targeted_macro_list = args.targeted_macro_list
        num_targeted_macros = len(open(targeted_macro_list).readlines())
        targeted_macro_array = [line.rstrip('\n') for line in open(targeted_macro_list, 'r').readlines()]

    if (not os.path.exists(args.workload_inst_list)):
        if (args.inst_fraction>=0.99):
            print("Instruction list not provided or incorrect. Setting instruction list as default ", inst_list)
        else:
            print("Selecting random instruction fraction of ", inst_fraction)
    else:
        workload_inst_list = args.workload_inst_list
        workload_num_insts = len(open(workload_inst_list).readlines())
        workload_inst_array = [line.rstrip('\n') for line in open(workload_inst_list, 'r').readlines()]
        print ("Workload Inst list ", workload_inst_list, "exists!!! Num insts:", workload_num_insts)
     

    #out = sp.Popen(['wc -l ', str(OUTPUT_DIR),'/inst_list.txt'], stdout=sp.PIPE, stderr=sp.STDOUT) 
    #stdout, stderr = out.communicate()
    #print("Num insts: "+str(stdout))
    coverage_file = str(OUTPUT_DIR) + '/macro_perinst_coverage_th' +str(sw_threshold)+'.txt'
    switching_file = str(OUTPUT_DIR) + '/macro_perinst_switching_th' +str(sw_threshold)+'.txt'
    wted_macro_file = str(OUTPUT_DIR) + '/wted_macro_th' +str(sw_threshold)+'.txt'
    residency_file = str(OUTPUT_DIR) + '/macro_perinst_residency_th' +str(sw_threshold)+'.txt'

    #Initialize lists 
    #a) cov_dict - complete dictionary with all instructions and macros
    #b) selected_cov_dict - dictionary with only selected intructions and all macros
    #c) pruned_cov_dict - dictionary with all instructions and macros with non zero switching in selected list

    inst_array = [line.rstrip('\n') for line in open(inst_list, 'r').readlines()]

    if (os.path.exists(args.workload_inst_list)):
        #Use Workload inst list
        print("Workload inst array selected")
        print(workload_inst_array)
        selected_inst_array = np.array(workload_inst_array)
        selected_indices = np.array([inst_array.index(x) for x in inst_array if x in workload_inst_array])
    elif(inst_fraction<0.99):	
        #Generate randomly selected instruction arrays
        selected_inst_array, selected_indices = gen_random_inst_list(inst_array, inst_fraction)  
    else:
        #Use default inst list
        selected_inst_array = inst_array
        selected_indices = np.arange(0,len(inst_array))

    #Read input files
    pruned_cov_dict, macros_per_inst = get_cov_dict_info(coverage_file, selected_indices, NUM_INSTS)
    wm_dict = get_wm_info(wted_macro_file)
    pruned_sw_dict, macro_sw_per_inst, macro_wted_sw_per_inst = get_sw_dict_info(switching_file, selected_indices, wm_dict, NUM_INSTS)
    pruned_res_dict, macro_res_per_inst = get_res_dict_info(residency_file, NUM_INSTS)

    if (os.path.exists(args.targeted_macro_list)):	
        targeted_cov_dict = dict((m, pruned_cov_dict[m])for m in targeted_macro_array)
        targeted_sw_dict = dict((m, pruned_sw_dict[m]) for m in targeted_macro_array)
        targeted_wm_dict = dict((m, 0) for m in wm_dict)   #Initialize targeted_wm_dict to 0
        selected_indices = np.arange(0,len(inst_array))	#Use all insts
        for m in targeted_macro_array:
            targeted_wm_dict[m] = wm_dict[m]
        tmp_pruned_sw_dict, tmp_macro_sw_per_inst, targeted_macro_wted_sw_per_inst = get_sw_dict_info(switching_file, selected_indices, targeted_wm_dict, NUM_INSTS) 	#Only last parameter needed
        inst_targeted_macro_wted_sw_dict = dict(zip(inst_array, targeted_macro_wted_sw_per_inst))

    else:
        targeted_cov_dict = pruned_cov_dict
        targeted_sw_dict = pruned_sw_dict
        targeted_wm_dict = wm_dict


    #Generate dictionaries
    inst_index_dict = dict(zip(inst_array,range(0,len(inst_array))))
    inst_macro_dict = dict(zip(inst_array, macros_per_inst))
    inst_macro_sw_dict = dict(zip(inst_array, macro_sw_per_inst))
    inst_macro_wted_sw_dict = dict(zip(inst_array, macro_wted_sw_per_inst))
    inst_macro_res_dict = dict(zip(inst_array, macro_res_per_inst))
    
    #Preserve original list
    init_inst_macro_sw_dict = inst_macro_sw_dict.copy()
    init_inst_macro_wted_sw_dict = inst_macro_wted_sw_dict.copy()
    init_inst_macro_res_dict = inst_macro_res_dict.copy()
    if (os.path.exists(args.targeted_macro_list)):	
        init_inst_targeted_macro_wted_sw_dict = inst_targeted_macro_wted_sw_dict.copy()
        if VERBOSE:
            print(len(init_inst_targeted_macro_wted_sw_dict))
    
    if (os.path.exists(args.targeted_macro_list)):	
        print("Targeted Macros: " +str(len(targeted_cov_dict)))    
        if VERBOSE:
            print(targeted_cov_dict)
        print("Macros with non-zero switching: " +str(len(targeted_sw_dict)))    
        if VERBOSE:
            print(targeted_sw_dict)
            #print(inst_targeted_macro_wted_sw_dict)
            print(init_inst_macro_wted_sw_dict)
 
    else:
        print("Total Macros: " +str(len(pruned_cov_dict)))    
        if VERBOSE:
            print(pruned_cov_dict)
        print("Macros with non-zero switching: " +str(len(pruned_sw_dict)))    
        if VERBOSE:
            print(pruned_sw_dict)

    #Recursive function to get list of instructions in stressmark
    stressmark_inst_list=[]
    #get_stressmark_inst( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    if (stressmk_type == "cov"):
        print ("Generating Coverage stressmark")
        get_stressmark_inst_cov( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    elif (stressmk_type == "sw"):
        get_stressmark_inst_sw( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    elif (stressmk_type == "wted_sw"):	
        get_stressmark_inst_wted_sw(pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_wted_sw_dict, wm_dict, stressmark_inst_list)    
    elif (stressmk_type == "macro_virus"): #only weighted switching	
        #get_stressmark_inst_wted_sw(targeted_cov_dict, targeted_sw_dict, inst_index_dict, inst_macro_dict, inst_targeted_macro_wted_sw_dict, targeted_wm_dict, stressmark_inst_list)    
        get_stressmark_inst_wted_sw(targeted_cov_dict, targeted_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_wted_sw_dict, targeted_wm_dict, stressmark_inst_list)    
    elif (stressmk_type == "res"):	# Default option for any core with no clock gating
        get_stressmark_inst_res( pruned_cov_dict, pruned_res_dict, inst_index_dict, inst_macro_dict, inst_macro_res_dict, stressmark_inst_list)    
    
    if(PRINT_INSTS):
        print("Print stressmark instructions")
        print(" ".join(stressmark_inst_list))

    #print("Switching vals")
    #print("Max inst lists: " +str(stressmark_inst_list))
    if(PRINT_WEIGHTS):
        print("Print stressmark instruction weights")
        if (stressmk_type == "cov"):
            min_val=min([init_inst_macro_sw_dict[inst] for inst in stressmark_inst_list])
            for inst in stressmark_inst_list:
                print(str(int(round(INST_SCALE_FACTOR*init_inst_macro_sw_dict[inst]/min_val))),' ',end='')
        elif (stressmk_type == "sw"):
            min_val=min([init_inst_macro_sw_dict[inst] for inst in stressmark_inst_list])
            for inst in stressmark_inst_list:
                print(str(int(round(INST_SCALE_FACTOR*init_inst_macro_sw_dict[inst]/min_val))),' ',end='')
        elif (stressmk_type == "wted_sw"):
            min_val=min([init_inst_macro_wted_sw_dict[inst] for inst in stressmark_inst_list])
            for inst in stressmark_inst_list:
                print(str(int(round(INST_SCALE_FACTOR*init_inst_macro_wted_sw_dict[inst]/min_val))),' ',end='')
        elif (stressmk_type == "macro_virus"):
            min_val=min([init_inst_targeted_macro_wted_sw_dict[inst] for inst in stressmark_inst_list])
            for inst in stressmark_inst_list:
                print(str(int(round(INST_SCALE_FACTOR*init_inst_targeted_macro_wted_sw_dict[inst]/min_val))),' ',end='')
        elif (stressmk_type == "res"):
            min_val=min([init_inst_macro_val_dict[inst] for inst in stressmark_inst_list])
            for inst in stressmark_inst_list:
                print(str(int(round(INST_SCALE_FACTOR*init_inst_macro_res_dict[inst]/min_val))),' ',end='')
           #print("Inst: "+str(inst) + " switching: " +str(init_inst_macro_sw_dict[inst]) + " Weight: " +str(int(round(INST_SCALE_FACTOR*init_inst_macro_sw_dict[inst]/min_sw))),' ',end='')
        print('')
    
    ## Write selected array to file
    #selected_inst_file = "/tmp/STRESSMARK_OUT/IF_"+str(inst_fraction)+"/selected_inst_list.txt"
    #with open(selected_inst_file, 'w') as f:
    #    for item in selected_inst_array:
    #        f.write("%s\n" % item)
            
if __name__ == "__main__":
   main()
