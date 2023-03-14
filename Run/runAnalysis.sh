#! /bin/bash

exit_on_error() {
    result=$1
    code=$2
    message=$3

    if [ $1 != 0 ]; then
        echo $3
        exit $2
    fi
} 

basedir="$(pwd)"
export SCRAM_ARCH=slc7_amd64_gcc700
source /cvmfs/cms.cern.ch/cmsset_default.sh
export HOME="/hdfs/store/user/hhe62/test_ZZ_jets/tmpHome" 
echo "Print new home directory:"
echo $HOME

seed=$1
seed2=$((seed+10))
nevt01j=$2
nevt2j=$3
nthd=$4

echo "nThreads: $nthd"
sed -i "s/seedholder/${seed2}/g" madspin_run.dat
sed -i "s/fileholder/${seed}.lhe/g" madspin_run.dat

tar -xf MG5_aMC_v2.6.5.tar.gz || exit_on_error $? 150 "Failed to unpack MadGraph--ErrorPattern"
mv madspin_run.dat MG5_aMC_v2_6_5
rm MG5_aMC_v2.6.5.tar.gz

mkdir unpack2j
mkdir unpack01j

cd unpack2j
tar -xf ../ZZTo4L012j_5f_NLO_FXFX_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz #2j gridpack despite the naming

./runcmsgrid.sh $nevt2j $seed 1 ||exit_on_error $? 151 "Error creating LHE events--ErrorPattern"
mv cmsgrid_final.lhe $basedir/${seed}_2j.lhe
#cp $basedir/${seed}_2j.lhe /hdfs/store/user/hhe62/test_ZZ_jets/debugLHE

cd ../unpack01j
tar -xf ../ZZTo4L01j_5f_NLO_FXFX_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz

./runcmsgrid.sh $nevt01j $seed 1 ||exit_on_error $? 151 "Error creating LHE events--ErrorPattern"
mv cmsgrid_final.lhe $basedir/${seed}_01j.lhe
#cp $basedir/${seed}_01j.lhe /hdfs/store/user/hhe62/test_ZZ_jets/debugLHE

cd ..
./mergeEvents.sh $seed $nevt01j $nevt2j ||exit_on_error $? 152 "Error merging events--ErrorPattern"
mv ${seed}.lhe MG5_aMC_v2_6_5 
scramv1 project CMSSW CMSSW_10_6_19
pushd CMSSW_10_6_19/src
eval $(scramv1 runtime -sh)
popd
#source cmssw_setup.sh
#cmssw_setup CMSSW_10_6_19.tar.gz

cd MG5_aMC_v2_6_5
./MadSpin/madspin madspin_run.dat ||exit_on_error $? 153 "Error decaying events--ErrorPattern"
mv ${seed}_decayed.lhe.gz $basedir/${seed}.lhe.gz

cd $basedir
gzip -d ${seed}.lhe.gz

cp _condor_stderr errfile
python examine_printout.py ||exit_on_error $? 157 "Error in printout examination--ErrorPattern"

genEvents=$(cat genEvents.txt)

if [ -r CMSSW_10_6_20/src ] ; then
  echo release CMSSW_10_6_20 already exists
else
  scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
eval $(scram runtime -sh)

mkdir -p Config/GEN/python
mv ../../fragment.py Config/GEN/python
mv ../../${seed}.lhe .
scram b ||exit_on_error $? 159 "Failed to build fragment--ErrorPattern"

#Gen
cmsDriver.py Config/GEN/python/fragment.py --filein file:${seed}.lhe --fileout file:GEN.root --mc --eventcontent RAWSIM --datatier GEN --conditions 106X_upgrade2018_realistic_v15_L1v1 --beamspot Realistic25ns13TeVEarly2018Collision --step GEN --geometry DB:Extended --era Run2_2018 --python_filename GEN_2018_cfg.py -n $genEvents --no_exec --nThreads $nthd 2>&1|| exit_on_error $? 159 "Failed to run Gen config--ErrorPattern"

cmsRun -e -j report0.xml GEN_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run Gen cmsRun--ErrorPattern"
nevt0=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report0.xml | tail -n 1)

#SIM
cmsDriver.py step2 --filein file:GEN.root --fileout file:SIM.root --mc --eventcontent RAWSIM --runUnscheduled --datatier GEN-SIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --beamspot Realistic25ns13TeVEarly2018Collision --step SIM --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename SIM_2018_cfg.py -n $nevt0 --no_exec 2>&1|| exit_on_error $? 159 "Failed to run SIM config--ErrorPattern"

cmsRun -e -j report1.xml SIM_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run SIM cmsRun--ErrorPattern"
nevt1=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report1.xml | tail -n 1)

#DIGI
cmsDriver.py step3 --filein file:SIM.root --fileout file:DIGIPremix.root  --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL18_106X_upgrade2018_realistic_v11_L1v1-v2/PREMIX" --mc --eventcontent PREMIXRAW --runUnscheduled --datatier GEN-SIM-DIGI --conditions 106X_upgrade2018_realistic_v15_L1v1 --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 --nThreads $nthd --geometry DB:Extended --datamix PreMix --era Run2_2018 --python_filename DIGIPremix_2018_cfg.py -n $nevt1 --no_exec > /dev/null || exit_on_error $? 159 "Failed to run DIGI config--ErrorPattern"

cmsRun -e -j report2.xml DIGIPremix_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run DIGI cmsRun--ErrorPattern"
nevt2=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report2.xml | tail -n 1)

pushd ../..
if [ -r CMSSW_10_2_16_UL/src ] ; then
  echo release CMSSW_10_2_16_UL already exists
else
  scram p CMSSW CMSSW_10_2_16_UL
fi
cd CMSSW_10_2_16_UL/src
eval $(scram runtime -sh)
popd

#HLT
cmsDriver.py step4 --filein file:DIGIPremix.root --fileout file:HLT.root --mc --eventcontent RAWSIM --datatier GEN-SIM-RAW --conditions 102X_upgrade2018_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2018v32 --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename HLT_2018_cfg.py -n $nevt2 --no_exec 2>&1 || exit_on_error $? 159 "Failed to run HLT config--ErrorPattern"

cmsRun -e -j report3.xml HLT_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run HLT cmsRun--ErrorPattern"
nevt3=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report3.xml | tail -n 1)

pushd ../..
if [ -r CMSSW_10_6_20/src ] ; then
  echo release CMSSW_10_6_20 already exists
else
  scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
eval $(scram runtime -sh)
popd

#RECO
cmsDriver.py step5 --filein file:HLT.root --fileout file:RECO.root --mc --eventcontent AODSIM --runUnscheduled --datatier AODSIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename RECO_2018_cfg.py -n $nevt3 --no_exec 2>&1 || exit_on_error $? 159 "Failed to run RECO config--ErrorPattern"

cmsRun -e -j report4.xml RECO_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run RECO cmsRun--ErrorPattern"
nevt4=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report4.xml | tail -n 1)

#miniAOD
cmsDriver.py step6 --filein file:RECO.root --fileout file:MiniAOD.root --mc --eventcontent MINIAODSIM --runUnscheduled --datatier MINIAODSIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --step PAT --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename MINIAOD_2018_cfg.py -n $nevt4 --no_exec 2>&1|| exit_on_error $? 159 "Failed to run miniAOD config--ErrorPattern"

cmsRun -e -j report5.xml MINIAOD_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run miniAOD cmsRun--ErrorPattern"
nevt5=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report5.xml | tail -n 1)

echo "Final Gen events: $nevt0"
echo "Final SIM events: $nevt1"
echo "Final DIGI events: $nevt2"
echo "Final HLT events: $nevt3"
echo "Final RECO events: $nevt4"
echo "Final miniAOD events: $nevt5"

cp ${seed}.lhe /hdfs/store/user/hhe62/test_ZZ_jets/LHEfiles
#cp SIM.root /hdfs/store/user/hhe62/test_ZZ_jets/genfiles/${seed}_GENSIM.root
cp MiniAOD.root /hdfs/store/user/hhe62/test_ZZ_jets/miniAODfiles/${seed}_miniAOD.root
