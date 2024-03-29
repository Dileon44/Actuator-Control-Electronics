#!/bin/bash

#############################################
################# VARIABLES #################
#############################################

# Files
cmpl_config_file="cmpl_config.vcf"
icarus_cmd_file="__$cmpl_config_file"

# Directories 
dir_out="out" # Directory for output files
dir_src="src" # Directory for UUT source files
dir_tb="tb"   # Directory for testbench files

create_vcd=1  # Create vcd file flag (0 - not create (also blocks coverage); !0 - create)
do_coverage=0 # Do coverage flag (0 - not to do; !0 - to do)

############################################
############### START SCRIPT ###############
############################################

if [ "$1" = "-help" ] || [ "$1" = "--help" ]; then
    echo -e  "Usage: go.sh [testname]"
    echo ""
    echo "Run tests for ControlDrive project."
    echo "Example usage: 'go.sh FormationPause_tb'."
    exit
# elif [[ $1 =~ ^ebp1_pld2_hl_test_[0-9]{3}$ ]]; then
elif [[ $1 =~ _tb$ ]] || [ "$1" = "Test" ]; then
    echo Running the test $1.
    # Specify the test name
    tb_name=$1
else
    echo Incorrect test name, terminating the script.
    exit
fi

# Check if output files directory exists and create one if necessary
if [ ! -d "$dir_out" ]; then
  mkdir $dir_out
fi

tb_file="$tb_name".sv

vvp_file="$tb_name".vvp
vcd_file="$tb_name".vcd

time_start=$(date +%s)
curr_date=$(date '+%d.%m.%Y')

# Add top file of the test to the compilation list
cp $cmpl_config_file $icarus_cmd_file
sed -i "1s/^/\t$dir_tb\/$tb_file\n\n/" "$icarus_cmd_file"

# Compile Verilog
iverilog -g2012 -c $icarus_cmd_file -o $vvp_file -DREPORT_DATE=\"$curr_date\"

# Check compilation result
if [[ $? != 0 ]]; then
  rm $icarus_cmd_file
  echo Compilation failure!
  rmdir $dir_out

else
  rm $icarus_cmd_file
  echo -e "Compilation completed successfuly.\n"

  if [ $create_vcd != 0 ]; then
    # Generate VCDs
    vvp -n $vvp_file

    if [[ $? != 0 ]]; then
      echo -e "Failed to generate VCD files!\n"

    else
      echo -e "VCD files are generated successfuly.\n"

      # Remove vvp file after the simulation has finished
      rm $vvp_file
    fi
  fi

  (( time_spent=$(date +%s)-$time_start ))
  (( time_spent_h=$time_spent/3600 ))
  (( time_spent_m=($time_spent%3600)/60 ))
  (( time_spent_s=$time_spent%60 ))

  printf "Process completed in:       %s.\n" $(date '+%H:%M:%S')
  printf "Duration of the simulation: %2d:%2d:%2d.\n\n" $time_spent_h $time_spent_m $time_spent_s
fi