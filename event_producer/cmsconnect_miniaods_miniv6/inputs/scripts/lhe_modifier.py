from __future__ import print_function
import argparse
import re
parser = argparse.ArgumentParser('Convert top benchmark h5 datasets to ROOT/awkd')
parser.add_argument('-m', '--mode', required=True, choices=['maskh1', 'maskh2', 'switch', 'correct'], help='Mode')
parser.add_argument('-i', '--inpath', required=True, help='Input file path')
parser.add_argument('-o', '--outpath', required=True, help='Output file path')
args = parser.parse_args()

def file_iterator(path):
    """Line-by-line iterator of a txt file"""
    with open(path, 'r') as f:
        for line in f:
            yield line

def mask_higgs(path, higgs_pos, outpath):
    begin_event = -999999
    with open(outpath, 'w') as fw:
        for line in file_iterator(path):
            if line.startswith('<event>'):
                begin_event = 0
                find_higgs_pos = 0
            if line.startswith('</event>'):
                begin_event = -999999
            if begin_event >= 0 and begin_event <= 15 and re.search('^\s+25', line):
                find_higgs_pos += 1
                if find_higgs_pos == higgs_pos:
                    line = re.sub('^(\s+)25', '\g<1>211025', line)
            fw.write(line)
            begin_event += 1

def manuplate_event(path, outpath, func):

    def write(lines, fw):
        fw.write(''.join(lines))
        return []

    record_lines = []
    with open(outpath, 'w') as fw:
        for line in file_iterator(path):
            if line.startswith('<event>'):
                record_lines = write(record_lines, fw)
            if line.startswith('</event>'):
                record_lines = func(record_lines)
                record_lines = write(record_lines, fw)

            record_lines.append(line)
        write(record_lines, fw)


def switch_higgs(record_lines):
    higgs_line_pos = []
    for il, l in enumerate(record_lines):
        if re.search('^\s+25', l):
            higgs_line_pos.append(il)
    assert len(higgs_line_pos) == 2
    il1, il2 = higgs_line_pos
    record_lines[il1], record_lines[il2] = record_lines[il2], record_lines[il1]
    return record_lines


def correct_decays(record_lines):
    # first change the mother pos of the 1st higgs decayed w+ w- or z+ z-
    for il in [7, 8]:
        record_lines[il] = re.sub('^(\s+[-]?2[34]\s+\d\s+)5(\s+)5', '\g<1>4\g<2>4', record_lines[il])

    # then correct the color flow for the second higgs decayed quarks
    exist_colors = []
    for il in [9, 10, 11, 12]:
        color = re.findall('^\s+[-]?\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)', record_lines[il])[0]
        color = max(map(int, color))
        if color > 0:
            exist_colors.append(color)
    if len(exist_colors): # necessary to change the following color flow
        color_move = len(set(exist_colors))
        for il in [15, 16, 17, 18]:
            color = list(re.findall('^\s+[-]?\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)', record_lines[il])[0])
            for ic in range(2):
                if int(color[ic]) > 0:
                    color[ic] = str(int(color[ic]) + color_move)
            record_lines[il] = re.sub('^(\s+[-]?\d+\s+\d+\s+\d+\s+\d+\s+)\d+(\s+)\d+', '\g<1>{c1}\g<2>{c2}'.format(c1=color[0], c2=color[1]), record_lines[il])

    return record_lines

if __name__ == '__main__':
    if args.mode == 'maskh1':
        mask_higgs(args.inpath, 1, args.outpath)
    if args.mode == 'maskh2':
        mask_higgs(args.inpath, 2, args.outpath)
    if args.mode == 'switch':
        manuplate_event(args.inpath, args.outpath, switch_higgs)
    if args.mode == 'correct':
        manuplate_event(args.inpath, args.outpath, correct_decays)


# python lhe_modifier.py -m switch -i /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final.lhe -o /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s.lhe
# ./JHUGen ReadLHE=/afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s.lhe DataFile=/afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu.lhe DecayMode1=5 DecayMode2=5
# python lhe_modifier.py -m switch -i /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu.lhe -o /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu_s.lhe
# ./JHUGen ReadLHE=/afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu_s.lhe DataFile=/afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu_s_jhu.lhe DecayMode1=5 DecayMode2=5
# python lhe_modifier.py -m correct -i /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu_s_jhu.lhe -o /afs/cern.ch/work/c/coli/hww/input/cmsgrid_final_s_jhu_s_jhu_c.lhe
