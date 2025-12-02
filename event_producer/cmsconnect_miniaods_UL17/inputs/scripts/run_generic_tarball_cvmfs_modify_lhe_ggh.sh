#!/bin/bash

#script to run generic lhe generation tarballs
#kept as simply as possible to minimize need
#to update the cmssw release
#(all the logic goes in the run script inside the tarball
# on frontier)
#J.Bendavid

#exit on first error
set -e

echo "   ______________________________________     "
echo "         Running Generic Tarball/Gridpack     "
echo "   ______________________________________     "

path=${1}
echo "gridpack tarball path = $path"

nevt=${2}
echo "%MSG-MG5 number of events requested = $nevt"

rnum=${3}
echo "%MSG-MG5 random seed used for the run = $rnum"

ncpu=${4}
echo "%MSG-MG5 thread count requested = $ncpu"

echo "%MSG-MG5 residual/optional arguments = ${@:5}"

if [ -n "${5}" ]; then
  use_gridpack_env=${5}
  echo "%MSG-MG5 use_gridpack_env = $use_gridpack_env"
fi

if [ -n "${6}" ]; then
  scram_arch_version=${6}
  echo "%MSG-MG5 override scram_arch_version = $scram_arch_version"
fi

if [ -n "${7}" ]; then
  cmssw_version=${7}
  echo "%MSG-MG5 override cmssw_version = $cmssw_version"
fi

LHEWORKDIR=`pwd`

if [ "$use_gridpack_env" = false -a -n "$scram_arch_version" -a -n  "$cmssw_version" ]; then
  echo "%MSG-MG5 CMSSW version = $cmssw_version"
  export SCRAM_ARCH=${scram_arch_version}
  scramv1 project CMSSW ${cmssw_version}
  cd ${cmssw_version}/src
  eval `scramv1 runtime -sh`
  cd $LHEWORKDIR
fi

if [[ -d lheevent ]]
    then
    echo 'lheevent directory found'
    echo 'Setting up the environment'
    rm -rf lheevent
fi
mkdir lheevent; cd lheevent

#untar the tarball directly from cvmfs
tar -xaf ${path} 

# If TMPDIR is unset, set it to the condor scratch area if present
# and fallback to /tmp
export TMPDIR=${TMPDIR:-${_CONDOR_SCRATCH_DIR:-/tmp}}

#generate events
./runcmsgrid.sh $nevt $rnum $ncpu ${@:5}

######### Modify the LHE file with an embeded script #########
cat > modify_lhe.py << 'EOF'
#!/usr/bin/env python3
import random

def process_lhe(infile, outfile):
    inside_event = False
    skip_first_line = False
    modify_next_three = False
    buffer_three = []  # store next three particle lines

    with open(infile, "r") as fin, open(outfile, "w") as fout:
        for line in fin:
            stripped = line.strip()

            # Detect start of an event
            if stripped == "<event>":
                inside_event = True
                skip_first_line = True
                modify_next_three = True
                buffer_three = []
                fout.write(line)
                continue

            # Detect end of an event block
            if stripped == "</event>":
                # If somehow an event ends before collecting 3 lines, flush what we have
                for l in buffer_three:
                    fout.write(l)
                buffer_three = []
                inside_event = False
                fout.write(line)
                continue

            if inside_event:
                # Skip the first line after <event>
                if skip_first_line:
                    fout.write(line)
                    skip_first_line = False
                    continue

                # Collect the next three particle lines
                if modify_next_three:
                    if len(buffer_three) < 3:
                        buffer_three.append(line)
                        # If we just stored the third line, time to modify
                        if len(buffer_three) == 3:
                            # Extract first integers
                            first_ints = []
                            for l in buffer_three:
                                parts = l.split()
                                first_ints.append(int(parts[0]))

                            # Expected pattern is [21, 21, 25]
                            # Modify based on 50/50 probability
                            if random.random() < 0.5:
                                new_vals = [2, -1, 37]
                            else:
                                new_vals = [-2, 1, -37]

                            # Rewrite the three lines
                            for i, l in enumerate(buffer_three):
                                parts = l.split()
                                parts[0] = str(new_vals[i])
                                new_line = " ".join(parts) + "\n"
                                fout.write(new_line)

                            # Done modifying — reset state
                            modify_next_three = False
                            buffer_three = []
                        continue

                # Normal lines inside the event after the first three particle lines
                fout.write(line)

            else:
                # Outside <event>, copy normally
                fout.write(line)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Modify LHE particle IDs with probabilistic replacement.")
    parser.add_argument("input", help="Input LHE file")
    parser.add_argument("output", help="Output LHE file")
    args = parser.parse_args()

    process_lhe(args.input, args.output)
EOF
chmod +x modify_lhe.py
./modify_lhe.py cmsgrid_final.lhe cmsgrid_final_mod.lhe
######## END #########

mv cmsgrid_final_mod.lhe $LHEWORKDIR/cmsgrid_final.lhe

cd $LHEWORKDIR

#cleanup working directory (save space on worker node for edm output)
rm -rf lheevent

exit 0

