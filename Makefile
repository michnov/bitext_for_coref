DATA_SET = sample
DATA_ID = pcedt

analyse_pcedt : data/${DATA_SET}.pcedt.analysed.list


data/${DATA_SET}.${DATA_ID}.analysed.list : data/${DATA_SET}.${DATA_ID}.list
	treex \
	Read::Treex from=@data/${DATA_SET}.pcedt.list \
	Util::Eval languages=en zone='$$zone->set_selector("ref");' \
	Util::Eval languages=cs zone='$$zone->set_selector("ref");' \
	Write::Treex path=data/analysed/${DATA_ID}/${DATA_SET}
	ls data/analysed/${DATA_ID}/${DATA_SET}/*.treex.gz > data/${DATA_SET}.${DATA_ID}.analysed.list
