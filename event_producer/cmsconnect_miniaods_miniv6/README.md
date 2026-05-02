# One-stop sample production for the MiniAODv6–NanoAODv15 workflow

This directory contains utilities for custom sample production, along with the corresponding "generator fragments" for various physics processes. The sample production is based on the MiniAODv6–NanoAODv15 routine (corresponding to the CMSSW_15_0_X release).

In the initial GEN step, an optional "instant MadGraph" technique is supported (as a substitute for conventional gridpacks), allowing direct event generation within MadGraph. For further details, refer to [`run_instMG.sh`](inputs/scripts/run_instMG.sh).

The list of supported physics processes will be continuously updated and extended below.

## Custom QCD samples for sfBDT training (2506)

This workflow includes the generation of bbb- and ccc-enriched QCD samples using MadGraph.

During the MiniAOD and NanoAOD steps, all pruning of generator-level particles is disabled to retain the full set of gen-particles produced by Pythia. The final output format is NanoAOD.

For both bbb- and ccc-enriched samples, six HT bins are defined. For each HT bin, 100,000 events are generated.

To submit the jobs (on cmsconnect)
```bash
cd <...>/cmsconnect_miniaods_miniv6  # enter this dir
mkdir log  # create the log dir
condor_submit jdl/sfbdt/submit_qcd_flvenriched.jdl
```

## Inference samples for validating GloParT under 24 era, for DPS note (2605)

### Dev note:

New setup for this miniv6 workflow, in `inputs/scripts`
 - run_instMG.sh script adapted from Run 3 folder (cmsconnect_miniaods_Run3)
 - JHU wrapper script updated to reuseSw version (those implemented in cmsconnect_miniaods_UL17)

Submitted jobs, in `jdl/test`
 - submit_infer_[hig3bin,hww3bin,w3bin,z3bin,t3bin]
 - special note: new samples for BulkGrav to WW or ZZ, and massive Higgs (spin-0) to ttbar, produced for the first time (remember that in UL17 we use official BSM samples to collect W/Z/t jets)
