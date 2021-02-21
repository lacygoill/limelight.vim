vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

const DEFAULT_COEFF: float = 0.5
const INVALID_COEFFICIENT: string = 'Invalid coefficient.  Expected: 0.0 ~ 1.0'
const GRAY_CONVERTER: dict<number> = {
    0: 231,
    7: 254,
    15: 256,
    16: 231,
    231: 256,
    }

# Interface {{{1
def limelight#execute( #{{{2
    bang: bool,
    visual: bool,
    line1: number,
    line2: number,
    ...args: list<string>
    )
    var range: list<number> = visual ? [line1, line2] : []
    if bang
        if len(args) > 0 && args[0] =~ '^!' && !IsOn()
            if len(args[0]) > 1
                On(range, args[0][1 : -1])
            else
                On(range)
            endif
        else
            Off()
        endif
    elseif len(args) > 0
        On(range, args[0])
    else
        On(range)
    endif
enddef

def limelight#operator(type = ''): string #{{{2
    if type == ''
        &opfunc = 'limelight#operator'
        return 'g@'
    endif
    limelight#execute(false, true, line("'["), line("']"))
    return ''
enddef
#}}}1
# Core {{{1
def Getpos(): list<number> #{{{2
    var bop: string = get(g:, 'limelight_bop', '^\s*$\n\zs')
    var eop: string = get(g:, 'limelight_eop', '^\s*$')
    var span: number = max([0,
        get(g:, 'limelight_paragraph_span', 0)
        -
        (getline('.')->Empty() ? 1 : 0)
        ])
    var pos: list<number> = getcurpos()
    var start: number
    for i in range(0, span)
        start = searchpos(bop, i == 0 ? 'cbW' : 'bW')[0]
    endfor
    setpos('.', pos)
    var end: number
    for _ in range(0, span)
        end = searchpos(eop, 'W')[0]
    endfor
    setpos('.', pos)
    return [start, end]
enddef

def Limelight() #{{{2
    if !get(w:, 'limelight_range', [])->empty()
        return
    endif
    if !exists('w:limelight_prev')
        w:limelight_prev = [0, 0, 0, 0]
    endif

    var curr: list<number> = [line('.'), line('$')]
    if curr == w:limelight_prev[0 : 1]
        return
    endif

    var paragraph: list<number> = Getpos()
    if paragraph == w:limelight_prev[2 : 3]
        return
    endif

    ClearHl()
    call(Hl, paragraph)
    w:limelight_prev = extend(curr, paragraph)
enddef

def Hl(startline: number, endline: number) #{{{2
    w:limelight_match_ids = get(w:, 'limelight_match_ids', [])
    add(w:limelight_match_ids,
        matchadd('LimelightDim', '\%<' .. startline .. 'l', 0))
    if endline > 0
        add(w:limelight_match_ids,
            matchadd('LimelightDim', '\%>' .. endline .. 'l', 0))
    endif
enddef

def ClearHl() #{{{2
    while exists('w:limelight_match_ids') && !empty(w:limelight_match_ids)
        sil! remove(w:limelight_match_ids, -1)->matchdelete()
    endwhile
enddef

def Coeff(arg_coeff: float): float #{{{2
    var coeff: float = arg_coeff < 0
        ?     get(g:, 'limelight_default_coefficient', DEFAULT_COEFF)
        :     arg_coeff
    if coeff < 0 || coeff > 1
        throw 'Invalid g:limelight_default_coefficient.  Expected: 0.0 ~ 1.0'
    endif
    return coeff
enddef

def Dim(coeff: float) #{{{2
    var synid: number = hlID('Normal')->synIDtrans()
    var fg: string = synIDattr(synid, 'fg#')
    var bg: string = synIDattr(synid, 'bg#')

    var dim: string
    if has('gui_running') || has('termguicolors') && &termguicolors
        if coeff < 0 && exists('g:limelight_conceal_guifg')
            dim = g:limelight_conceal_guifg
        elseif empty(fg) || empty(bg)
            throw Unsupported()
        else
            var _coeff: float = Coeff(coeff)
            var fg_rgb: list<number> = Hex2rgb(fg)
            var bg_rgb: list<number> = Hex2rgb(bg)
            var dim_rgb: list<float> = [
                bg_rgb[0] * _coeff + fg_rgb[0] * (1 - _coeff),
                bg_rgb[1] * _coeff + fg_rgb[1] * (1 - _coeff),
                bg_rgb[2] * _coeff + fg_rgb[2] * (1 - _coeff),
                ]
            dim = '#'
                .. mapnew(dim_rgb, (_, v: float): string => float2nr(v)->printf('%x'))
                    ->join('')
        endif
        exe printf('hi LimelightDim guifg=%s guisp=bg', dim)
    elseif str2nr(&t_Co) == 256
        if coeff < 0 && exists('g:limelight_conceal_ctermfg')
            dim = g:limelight_conceal_ctermfg
        elseif str2nr(fg) <= -1 || str2nr(bg) <= -1
            throw Unsupported()
        else
            var _coeff: float = Coeff(coeff)
            fg = GrayContiguous(fg)
            bg = GrayContiguous(bg)
            dim = float2nr(str2nr(bg) * _coeff + str2nr(fg) * (1 - _coeff))->GrayAnsi()
        endif
        if typename(dim) == 'string'
            exe printf('hi LimelightDim ctermfg=%s', dim)
        else
            exe printf('hi LimelightDim ctermfg=%d', dim)
        endif
    else
        throw 'Unsupported terminal.  Sorry.'
    endif
enddef

def ParseCoeff(coeff: any): float #{{{2
    var t: number = type(coeff)
    var c: float
    if t == 1
        if coeff =~ '^ *[0-9.]\+ *$'
            c = str2float(coeff)
        else
            throw INVALID_COEFFICIENT
        endif
    elseif index([0, 5], t) >= 0
        c = t + 0.0
    else
        throw INVALID_COEFFICIENT
    endif
    return c
enddef

def On(range: list<number>, coeff: any = '') #{{{2
    limelight_coeff = coeff != '' ? ParseCoeff(coeff) : -1.0
    Dim(limelight_coeff)

    w:limelight_range = range
    if !empty(range)
        ClearHl()
        call(Hl, range)
    endif

    augroup limelight
        var was_on: bool = exists('#limelight#CursorMoved')
        au!
        if empty(range) || was_on
            au CursorMoved,CursorMovedI * Limelight()
        endif
        au ColorScheme * try
            |     Dim(limelight_coeff)
            | catch
            |     Off()
            |     throw v:exception
            | endtry
    augroup END

    # FIXME: We cannot safely remove this group once Limelight started
    augroup LimelightCleanup | au!
        au WinEnter * Cleanup()
    augroup END

    if exists('#CursorMoved')
        do <nomodeline> CursorMoved
    endif
enddef
var limelight_coeff: float

def Off() #{{{2
    ClearHl()
    augroup limelight | au!
    augroup END
    augroup! limelight
    unlet! w:limelight_prev w:limelight_match_ids w:limelight_range
enddef

def Cleanup() #{{{2
    if !IsOn()
        ClearHl()
    end
enddef
#}}}1
# Utilities {{{1
def Hex2rgb(arg_str: string): list<number> #{{{2
    var str: string = trim(arg_str, '#')
    return [
        eval('0x' .. str[0 : 1]),
        eval('0x' .. str[2 : 3]),
        eval('0x' .. str[4 : 5])
        ]
enddef

def IsOn(): bool #{{{2
    return exists('#limelight')
enddef

def Unsupported(): string #{{{2
    var name: string = 'g:limelight_conceal_' .. (has('gui_running') ? 'gui' : 'cterm') .. 'fg'

    if exists(name)
        return 'Cannot calculate background color.'
    else
        return 'Unsupported color scheme. ' .. name .. ' required.'
    endif
enddef

def Empty(line: string): bool #{{{2
    return line =~ '^\s*$'
enddef

def GrayContiguous(arg_col: string): string #{{{2
    var col: number = arg_col->str2nr()
    var val: number = get(GRAY_CONVERTER, col, col)
    if val < 231 || val > 256
        throw Unsupported()
    endif
    return val->string()
enddef

def GrayAnsi(col: number): string #{{{2
    return (col == 231 ? 0 : (col == 256 ? 231 : col))->string()
enddef

