vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

command -nargs=? -bar -bang -range Limelight limelight#execute(<bang>0, <count> > 0, <line1>, <line2>, <f-args>)

nnoremap <expr><unique> ++ limelight#operator()
nnoremap <expr><unique> +++ limelight#operator() .. '_'
xnoremap <unique> ++ <C-\><C-N><Cmd>:* Limelight<CR>

# stop
nnoremap <unique> +- <Cmd>Limelight!<CR>
