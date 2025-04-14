#!/usr/bin/python3

from pathlib import Path
import subprocess

D_FROM="/FPGA/proj150/proj150.srcs/sources_1/imports/"
D_TO="/FPGA/cs150/hardware/"
SHELL_cmd=["diff", "-q"]

def exec_cmd(args):
    """
    Execute the comparison or copy command on the current pair of files
    """
    #print(f"### {args}")
    subprocess.run(args)

def parse_line(line):
    """
    Split the line into parameters.
    """
    params = line.strip().split()   # Example: split by whitespace
    return params

def parse_file(filepath):
    """
    Read and parse the file line by line.
    """
    with open(filepath, 'r') as file:
        for line_number, line in enumerate(file, start=1):
            params = parse_line(line)
            SHELL_args = SHELL_cmd.copy()
            if len(params) == 0:
                continue
            elif len(params) == 1:
                SHELL_args.extend([D_FROM+params[0], D_TO+params[0]])
            else:
                SHELL_args.extend([params[0], params[1]])
            #print(f"Line {line_number}: {SHELL_args}")
            exec_cmd(SHELL_args)

if __name__ == "__main__":
    file_path = "map-src.txt"
    parse_file(file_path)


### NOTEST ###
#file_path = Path("/home/user/documents/report.txt")
#directory = file_path.parent
#filename = file_path.stem
#extension = file_path.suffix


# Call a simple system command, like 'ls' or 'dir'
#result = subprocess.run(["ls", "-l"], capture_output=True, text=True)

# Print the output
#print("STDOUT:\n", result.stdout)
#print("STDERR:\n", result.stderr)
#print("Return Code:", result.returncode)
