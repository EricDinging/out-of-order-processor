gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier build/rs.cov.simv.vdb -testdir {} -test {} -merge MergedTest -db_max_tests 10 -fsm transition
verdiWindowResize -win $_vdCoverage_1 "510" "190" "1005" "711"
verdiWindowResize -win $_vdCoverage_1 "0" "0" "1005" "741"
vdCovExit -noprompt
