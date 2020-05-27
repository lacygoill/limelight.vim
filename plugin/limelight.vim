if exists('g:loaded_limelight')
    finish
endif
let g:loaded_limelight = 1

com -nargs=? -bar -bang -range Limelight call limelight#execute(<bang>0, <count> > 0, <line1>, <line2>, <f-args>)

nno <expr><unique> ++  limelight#operator()
nno <expr><unique> +++ limelight#operator()..'_'
xno <unique><silent> ++  :Limelight<cr>

" stop
nno <unique><silent> +- :<c-u>Limelight!<cr>
