vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

com -nargs=? -bar -bang -range Limelight limelight#execute(<bang>0, <count> > 0, <line1>, <line2>, <f-args>)

nno <expr><unique> ++ limelight#operator()
nno <expr><unique> +++ limelight#operator() .. '_'
xno <unique> ++ <c-\><c-n><cmd>* Limelight<cr>

# stop
nno <unique> +- <cmd>Limelight!<cr>
