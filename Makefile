SHELL=/bin/bash

DATA_SET = train
DATA_ID = pcedt

JOBS_NUM = 50

ifeq (${DATA_SET}, train)
JOBS_NUM = 100
endif

LRC=1
ifeq (${LRC}, 1)
LRC_FLAGS = -p --qsub '-hard -l mem_free=8G -l act_mem_free=8G -l h_vmem=8G' --jobs ${JOBS_NUM}
endif

morpho_pcedt : data/${DATA_SET}.pcedt.analysed.morpho.list
data/${DATA_SET}.${DATA_ID}.analysed.morpho.list : data/${DATA_SET}.${DATA_ID}.list
	treex ${LRC_FLAGS} \
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
	treex ${LRC_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.${DATA_ID}.analysed.morpho.list \
	Align::A::InsertAlignmentFromFile from=data/analysed/${DATA_ID}/${DATA_SET}/giza.gz \
	           inputcols=gdfa_int_left_right_revgdfa_therescore_backscore \
			              selector=src language=cs to_selector=src to_language=en \
	scenarios/s3_parsing.scen \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET} stem_suffix=.parsed
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.parsed.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.parsed.list

gold_system_pcedt : data/${DATA_SET}.pcedt.analysed.list
data/${DATA_SET}.${DATA_ID}.analysed.list : data/${DATA_SET}.${DATA_ID}.analysed.parsed.list
	treex ${LRC_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.${DATA_ID}.analysed.parsed.list \
	scenarios/align_src_ref.scen \
	Write::Treex clobber=1 path=data/analysed/${DATA_ID}/${DATA_SET} stem_suffix=.final
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.final.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.list

#data/${DATA_SET}.${DATA_ID}.analysed.list : data/${DATA_SET}.${DATA_ID}.list
#	treex ${LRC_FLAGS} \
	Read::Treex from=@data/${DATA_SET}.pcedt.list \
	Util::Eval language=en zone='$$zone->set_selector("ref");' \
	Util::Eval language=cs zone='$$zone->set_selector("ref");' \
	scenarios/prepare_for_analysis.scen \
	scenarios/analysis.en.scen \
	scenarios/analysis.cs.scen \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET}
#	ls data/analysed/${DATA_ID}/${DATA_SET}/*.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.list

bitext_coref_stats :
	-treex $(LRC_FLAGS) \
		Read::Treex from=@data/$(DATA_SET).$(DATA_ID).analysed.list \
		Util::SetGlobal selector=all \
		Util::SetGlobal language=all \
		My::BitextCorefStats to='.' substitute='{^.*train/(.*)}{tmp/stats/$$1.txt}'
	find tmp/stats -path "*.txt" -exec cat {} \; > stats/bitext_coref_stats
	#cat stats/bitext_coref_stats | grep "^cs_relpron_scores" | cut -f2 | scripts/eval.pl > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/scores.all
	#cat stats/bitext_coref_stats | grep "^cs_relpron_scores" | cut -f2,3 | grep "^0" | cut -f2 > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/nodes.0_ref.list
	#cat stats/bitext_coref_stats | grep "^cs_relpron_en_counterparts" | cut -f2 | distr > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/en_counterparts.freq
	#cat stats/bitext_coref_stats | grep "^cs_relpron_tlemma" | cut -f2 | distr > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/tlemma.freq
	#cat stats/bitext_coref_stats | grep "^cs_relpron_ante_agree" | cut -f2 | scripts/eval.pl | sed 's/PRE/ali\/cs/' | sed 's/REC/ali\/en/' | sed '/ACC/d;sed/F-M/d' > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/ante_agree.all.scores
	cat stats/bitext_coref_stats | grep "^en_perspron_cs_counterparts" | cut -f2 | distr > analysis/en.perspron/$(DATA_SET).$(DATA_ID)/cs.counterparts.freq

en_perspron_stats :
	-treex $(LRC_FLAGS) -Len -Ssrc \
		Read::Treex from=@data/$(DATA_SET).$(DATA_ID).analysed.list \
		My::BitextCorefStats::EnPerspron align_selector=$(ALIGN_SELECTOR) to='.' substitute='{^.*train/(.*)}{tmp/stats/en_perspron/$$1.txt}'
	find tmp/stats/en_perspron -path "*.txt" -exec cat {} \; > tmp/stats/en_perspron.all
	#cat stats/bitext_coref_stats | grep "^cs_relpron_scores" | cut -f2 | scripts/eval.pl > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/scores.all
	#cat stats/bitext_coref_stats | grep "^cs_relpron_scores" | cut -f2,3 | grep "^0" | cut -f2 > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/nodes.0_ref.list
	#cat stats/bitext_coref_stats | grep "^cs_relpron_en_counterparts" | cut -f2 | distr > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/en_counterparts.freq
	#cat stats/bitext_coref_stats | grep "^cs_relpron_tlemma" | cut -f2 | distr > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/tlemma.freq
	#cat stats/bitext_coref_stats | grep "^cs_relpron_ante_agree" | cut -f2 | scripts/eval.pl | sed 's/PRE/ali\/cs/' | sed 's/REC/ali\/en/' | sed '/ACC/d;sed/F-M/d' > analysis/cs.relpron/$(DATA_SET).$(DATA_ID)/ante_agree.all.scores
	cat tmp/stats/en_perspron.all | grep "^en_perspron_cs_counterparts" | cut -f2 | distr > analysis/en.perspron/$(DATA_SET).$(DATA_ID)/cs.$(ALIGN_SELECTOR).counterparts.freq

