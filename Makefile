SHELL=/bin/bash

DATA_SET = sample
DATA_ID = pcedt

JOBS_NUM = 50

ifeq (${DATA_SET}, train)
JOBS_NUM = 50
endif

ifneq (${DATA_SET}, sample)
CLUSTER_FLAGS = -p --qsub '-hard -l mem_free=8G -l act_mem_free=8G -l h_vmem=8G' --jobs ${JOBS_NUM}
endif

morpho_pcedt : data/${DATA_SET}.pcedt.analysed.morpho.list
data/${DATA_SET}.${DATA_ID}.analysed.morpho.list : data/${DATA_SET}.${DATA_ID}.list
	treex ${CLUSTER_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.pcedt.list \
	Util::Eval language=en zone='$$zone->set_selector("ref");' \
	Util::Eval language=cs zone='$$zone->set_selector("ref");' \
	scenarios/prepare_for_analysis.scen \
	scenarios/s1_morpho.scen \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET} stem_suffix=.morpho \
	Write::LemmatizedBitexts selector=src language=cs to_language=en to_selector=src \
	| gzip -c > data/analysed/${DATA_ID}/${DATA_SET}/for_giza.gz
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.morpho.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.morpho.list

#	qsubmit --disk=400g --mem=40g --jobname=giza.gz \
        | paste <(zcat $< | cut -f1 | sed 's/hali.gz/morpho.treex.gz/') - \
		--mgizadir=$(shell pwd)/src/mgizapp/ $< \

giza_pcedt : data/analysed/${DATA_ID}/${DATA_SET}/giza.gz
data/analysed/${DATA_ID}/${DATA_SET}/giza.gz : data/analysed/${DATA_ID}/${DATA_SET}/for_giza.gz   
	bin/gizawrapper.pl \
        --tempdir=/mnt/h/tmp \
        --bindir=$(shell pwd)/bin $< \
        --lcol=1 --rcol=2 \
        --keep \
        --dirsym=gdfa,int,left,right,revgdfa \
		| paste <(zcat $< | cut -f1 | sed 's/^.*\(wsj.*\)$$/data\/analysed\/${DATA_ID}\/${DATA_SET}\/\1/' | sed 's/treex/morpho\.treex/') - \
        | gzip > $@

analyse_pcedt : data/${DATA_SET}.pcedt.analysed.parsed.list
data/${DATA_SET}.${DATA_ID}.analysed.parsed.list : data/${DATA_SET}.${DATA_ID}.analysed.morpho.list data/analysed/${DATA_ID}/${DATA_SET}/giza.gz
	treex ${CLUSTER_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.${DATA_ID}.analysed.morpho.list \
	Align::A::InsertAlignmentFromFile from=data/analysed/${DATA_ID}/${DATA_SET}/giza.gz \
	           inputcols=gdfa_int_left_right_revgdfa_therescore_backscore \
			              selector=src language=cs to_selector=src to_language=en \
	scenarios/s3_parsing.scen \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET} stem_suffix=.parsed
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.parsed.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.parsed.list

gold_system_pcedt : data/${DATA_SET}.pcedt.analysed.list
data/${DATA_SET}.${DATA_ID}.analysed.list : data/${DATA_SET}.${DATA_ID}.analysed.parsed.list
	treex ${CLUSTER_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.${DATA_ID}.analysed.parsed.list \
	scenarios/align_src_ref.scen \
	Write::Treex clobber=1 path=data/analysed/${DATA_ID}/${DATA_SET} stem_suffix=.final
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.final.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.list

#data/${DATA_SET}.${DATA_ID}.analysed.list : data/${DATA_SET}.${DATA_ID}.list
#	treex ${CLUSTER_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.pcedt.list \
	Util::Eval language=en zone='$$zone->set_selector("ref");' \
	Util::Eval language=cs zone='$$zone->set_selector("ref");' \
	scenarios/prepare_for_analysis.scen \
	scenarios/analysis.en.scen \
	scenarios/analysis.cs.scen \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET}
#	ls data/analysed/${DATA_ID}/${DATA_SET}/*.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.list
