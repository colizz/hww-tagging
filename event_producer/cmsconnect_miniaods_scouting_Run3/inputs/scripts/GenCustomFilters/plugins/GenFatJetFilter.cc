// CMSSW include files
#include "FWCore/Framework/interface/Frameworkfwd.h"
#include "FWCore/Framework/interface/MakerMacros.h"
#include "FWCore/Framework/interface/EventSetup.h"
#include "FWCore/Framework/interface/stream/EDFilter.h"
#include "FWCore/ParameterSet/interface/ParameterSet.h"

#include "DataFormats/JetReco/interface/GenJetCollection.h"

// C++ include files
#include <memory>
#include <map>

using namespace edm;
using namespace std;

//
// class declaration
//

class GenFatJetFilter : public edm::stream::EDFilter<> {
public:
  explicit GenFatJetFilter(const edm::ParameterSet&);
  ~GenFatJetFilter() override;

private:
  bool filter(edm::Event&, const edm::EventSetup&) override;

private:
  
  double minPt_;
  double maxPt_;
  double minMass_;
  double maxMass_;
  
  // Input tags
  edm::EDGetTokenT< reco::GenJetCollection > inputTag_GenJetCollection_;
};


GenFatJetFilter::GenFatJetFilter(const edm::ParameterSet& iConfig) :
  minPt_(iConfig.getUntrackedParameter<double>("minPt", 440.)),
  maxPt_(iConfig.getUntrackedParameter<double>("maxPt", -1.)),
  minMass_(iConfig.getUntrackedParameter<double>("minMass", 80.)),
  maxMass_(iConfig.getUntrackedParameter<double>("maxMass", 160.)),
  inputTag_GenJetCollection_(consumes<reco::GenJetCollection>(iConfig.getUntrackedParameter<edm::InputTag>("inputTag_GenJetCollection", edm::InputTag("ak8GenJetsNoNu")))) {
    
}

GenFatJetFilter::~GenFatJetFilter(){
  
}

// ------------ method called to skim the data  ------------
bool GenFatJetFilter::filter(edm::Event& iEvent, const edm::EventSetup& iSetup)
{
  Handle< vector<reco::GenJet> > handleGenJets;
  iEvent.getByToken(inputTag_GenJetCollection_, handleGenJets);
  const vector<reco::GenJet>* genJets = handleGenJets.product();
  
  // Getting filtered generator jets
  bool flag = false;
  for(unsigned i=0; i<genJets->size(); i++){
    const reco::GenJet* j = &((*genJets)[i]);
    if(j->pt() > minPt_ && (maxPt_ < 0 || j->pt() < maxPt_) && j->mass() > minMass_ && (maxMass_ < 0 || j->mass() < maxMass_)) {
      flag = true;
      break;
    }
  }
  return flag;
}

//define this as a plug-in
DEFINE_FWK_MODULE(GenFatJetFilter);
