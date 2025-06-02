import FWCore.ParameterSet.Config as cms

genFatJetFilter = cms.EDFilter("GenFatJetFilter",
    inputTag_GenJetCollection = cms.untracked.InputTag('ak8GenJetsNoNu'),
    minPt = cms.untracked.double(440.),
    maxPt = cms.untracked.double(-1),
    minMass = cms.untracked.double(80.),
    maxMass = cms.untracked.double(160.),
)
