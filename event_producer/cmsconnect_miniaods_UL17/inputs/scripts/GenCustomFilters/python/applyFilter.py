import FWCore.ParameterSet.Config as cms

def apply(process):
    process.load('GeneratorInterface.GenCustomFilters.genFatJetFilter_cfi')
    process.pgen = cms.Sequence(process.pgen * process.genFatJetFilter)
    return process
