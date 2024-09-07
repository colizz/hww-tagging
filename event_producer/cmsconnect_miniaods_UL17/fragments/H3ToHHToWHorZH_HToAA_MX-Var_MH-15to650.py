import FWCore.ParameterSet.Config as cms

#Link to datacards:
#https://github.com/cms-sw/genproductions/tree/master/bin/MadGraph5_aMCatNLO/cards/production/2017/13TeV/BulkGraviton_hh_granular
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunes2017.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8GeneratorFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.),
    RandomizedParameters = cms.VPSet(),
)

import numpy as np
# low mass list
low_m_higgs = np.array([15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250])
low_m_res = np.arange(600, 6000, 100)

# high mass list
m_higgs = np.arange(260, 660, 10)
# # minimum m_res changes s.t. it is always > 2x m_higgs to avoid off-shell Higgses
# m_res_min = np.linspace(600, 1600, len(m_higgs))  

# reweight points such that there are the same number of events at 260 as 250 GeV
# and then continuously decrease the weight from there till 650 GeV
num_low_points = float(len(low_m_higgs))
num_high_points = float(len(m_higgs))

# solve system of equations s.t. 1) total weight sums to 1, and 2) the first weight is 1 / (# of low points) i.e. same # of events as 260 GeV
m = np.array([[num_high_points, num_high_points * (num_high_points - 1) / 2], [1, num_high_points]])
b = np.array([1.0, 1.0 / num_low_points])
# a is smallest weight, d is spacing between weights
a, d = np.linalg.solve(m, b)


def mh_weight(mh):
    idx = np.where(m_higgs == mh)[0][0]
    return a + d * (len(m_higgs) - idx - 1)


def mres_min(mh):
    """Choose mX for mH s.t. mX^2 - 4mH^2 remains constant for each mH"""
    mdel = 600**2 - 4 * 250**2
    return np.sqrt(mdel + 4 * mh ** 2)


def pset(gp_name, mx, mh, m2p, maa, weight):

    # process: resonance X (H3) -> H2 H2 or H+ H-
    #   - H2 -> Z H1, Z -> 2-prong, H1 -> gamma gamma
    #   - H+ -> W H1, W -> 2-prong, H1 -> gamma gamma
    # mX, mH (H2/H+-), m2p (W/Z), maa (H1): all variable masses
    return cms.PSet(
        ConfigWeight = cms.double(weight),
        GridpackPath =  cms.string('instMG://%s/MG5_aMC_v2.6.5/%.0f:%.0f' % (gp_name, mx, mh)),
        ConfigDescription = cms.string('%s_MX%.0f_MH%.0f_M2p%.1f_Maa%.1f' % (gp_name, mx, mh, m2p, maa)),
        PythiaParameters = cms.PSet(
            pythia8CommonSettingsBlock,
            pythia8CP5SettingsBlock,
            pythia8PSweightsSettingsBlock,
            processParameters = cms.vstring(
                '35:onMode = off',
                '35:oneChannel = 1 1.000000 100 23 25', # H2 -> Z H1, Z -> 2-prong, H1 -> gamma gamma
                '37:onMode = off',
                '37:oneChannel = 1 1.000000 100 24 25', # H+- -> W H1, W -> 2-prong, H1 -> gamma gamma
                '23:onMode = off',
                '23:oneChannel = 1 0.100000 100 5 -5',
                '23:addChannel = 1 0.100000 100 4 -4',
                '23:addChannel = 1 0.100000 100 3 -3',
                '23:addChannel = 1 0.100000 100 2 -2',
                '23:addChannel = 1 0.100000 100 1 -1',
                '23:addChannel = 1 0.100000 100 21 21',
                '23:addChannel = 1 0.133333 100 11 -11',
                '23:addChannel = 1 0.133333 100 13 -13',
                '23:addChannel = 1 0.133334 100 15 -15',
                '23:m0 = %.1f' % m2p,
                '23:mMin = 0.000001',
                '24:onMode = off',
                '24:oneChannel = 1 0.100000 100 -1 2',
                '24:addChannel = 1 0.100000 100 -3 2',
                '24:addChannel = 1 0.100000 100 -5 2',
                '24:addChannel = 1 0.100000 100 -1 4',
                '24:addChannel = 1 0.100000 100 -3 4',
                '24:addChannel = 1 0.100000 100 -5 4',
                '24:addChannel = 1 0.133333 100 -11 12',
                '24:addChannel = 1 0.133333 100 -13 14',
                '24:addChannel = 1 0.133334 100 -15 16',
                '24:m0 = %.1f' % m2p,
                '24:mMin = 0.000001',
                '25:onMode = off',
                '25:oneChannel = 1 1.00000 100 22 22',
                '25:m0 = %.1f' % maa,
                '25:mMin = 0.000001',
                'ResonanceDecayFilter:filter = on'
            ),
            parameterSets = cms.vstring(
                'pythia8CommonSettings',
                'pythia8CP5Settings',
                'pythia8PSweightsSettings',
                'processParameters',
            )
        )
    )


# generate random mass ratios for m2p/mh and maa/mh
# this is a hack because it makes the config not reproducible. But with many events repeatedly produced with this config, it should be fine
# if we include all m2p and maa points, the gridpack choices become too many and memory usage explodes
import random
def generate_mass_ratios():
    while True:
        num1 = random.uniform(0.2, 0.8)
        num2 = random.uniform(0.2, 0.8)
        if num1 + num2 < 0.95:
            return num1, num2


# append low-mass points
for mh in low_m_higgs:
    for mx in low_m_res:
        # print('H3ToHH_2HDM_MX%.0f_MH%.0f weight 1.0' % (mx, mh))
        num1, num2 = generate_mass_ratios()
        generator.RandomizedParameters.append(pset('H3ToH2H2_2HDM', mx, mh, mh * num1, mh * num2, 1.0))
        num1, num2 = generate_mass_ratios()
        generator.RandomizedParameters.append(pset('H3ToHpHm_2HDM', mx, mh, mh * num1, mh * num2, 1.0))

# append high-mass points
for mh in m_higgs:
    m_res = np.linspace(mres_min(mh), mres_min(mh) * 10, len(low_m_res), endpoint=False)
    weight = mh_weight(mh)
    for mx in m_res:
        # print('H3ToHH_2HDM_MX%.0f_MH%.0f weight %.5f' % (mx, mh, weight))
        num1, num2 = generate_mass_ratios()
        generator.RandomizedParameters.append(pset('H3ToH2H2_2HDM', mx, mh, mh * num1, mh * num2, weight))
        num1, num2 = generate_mass_ratios()
        generator.RandomizedParameters.append(pset('H3ToHpHm_2HDM', mx, mh, mh * num1, mh * num2, weight))
