let s:default_coeff = str2float('0.5')
let s:invalid_coefficient = 'Invalid coefficient.  Expected: 0.0 ~ 1.0'

fu s:unsupported() abort
    let var = 'g:limelight_conceal_' .. (has('gui_running') ? 'gui' : 'cterm') .. 'fg'

    if exists(var)
        return 'Cannot calculate background color.'
    else
        return 'Unsupported color scheme. ' .. var .. ' required.'
    endif
endfu

fu s:getpos() abort
    let bop = get(g:, 'limelight_bop', '^\s*$\n\zs')
    let eop = get(g:, 'limelight_eop', '^\s*$')
    let span = max([0, get(g:, 'limelight_paragraph_span', 0) - getline('.')->s:empty()])
    let pos = getcurpos()
    for i in range(0, span)
        let start = searchpos(bop, i == 0 ? 'cbW' : 'bW')[0]
    endfor
    call setpos('.', pos)
    for _ in range(0, span)
        let end = searchpos(eop, 'W')[0]
    endfor
    call setpos('.', pos)
    return [start, end]
endfu

fu s:empty(line) abort
    return (a:line =~# '^\s*$')
endfu

fu s:limelight() abort
    if !get(w:, 'limelight_range', [])->empty()
        return
    endif
    if !exists('w:limelight_prev')
        let w:limelight_prev = [0, 0, 0, 0]
    endif

    let curr = [line('.'), line('$')]
    if curr == w:limelight_prev[0 : 1]
        return
    endif

    let paragraph = s:getpos()
    if paragraph == w:limelight_prev[2 : 3]
        return
    endif

    call s:clear_hl()
    call call('s:hl', paragraph)
    let w:limelight_prev = extend(curr, paragraph)
endfu

fu s:hl(startline, endline) abort
    let w:limelight_match_ids = get(w:, 'limelight_match_ids', [])
    let priority = get(g:, 'limelight_priority', 10)
    call add(w:limelight_match_ids, matchadd('LimelightDim', '\%<' .. a:startline .. 'l', priority))
    if a:endline > 0
        call add(w:limelight_match_ids, matchadd('LimelightDim', '\%>' .. a:endline .. 'l', priority))
    endif
endfu

fu s:clear_hl() abort
    while exists('w:limelight_match_ids') && !empty(w:limelight_match_ids)
        sil! call remove(w:limelight_match_ids, -1)->matchdelete()
    endwhile
endfu

fu s:hex2rgb(str) abort
    let str = trim(a:str, '#')
    return [eval('0x' .. str[0:1]), eval('0x'.str[2:3]), eval('0x'.str[4:5])]
endfu

let s:gray_converter = {
    \ 0: 231,
    \ 7: 254,
    \ 15: 256,
    \ 16: 231,
    \ 231: 256,
    \ }

fu s:gray_contiguous(col) abort
    let val = get(s:gray_converter, a:col, a:col)
    if val < 231 || val > 256
        throw s:unsupported()
    endif
    return val
endfu

fu s:gray_ansi(col) abort
    return a:col == 231 ? 0 : (a:col == 256 ? 231 : a:col)
endfu

fu s:coeff(coeff) abort
    let coeff = a:coeff < 0 ?
        \ get(g:, 'limelight_default_coefficient', s:default_coeff) : a:coeff
    if coeff < 0 || coeff > 1
        throw 'Invalid g:limelight_default_coefficient.  Expected: 0.0 ~ 1.0'
    endif
    return coeff
endfu

fu s:dim(coeff) abort
    let synid = hlID('Normal')->synIDtrans()
    let fg = synIDattr(synid, 'fg#')
    let bg = synIDattr(synid, 'bg#')

    if has('gui_running') || has('termguicolors') && &termguicolors
        if a:coeff < 0 && exists('g:limelight_conceal_guifg')
            let dim = g:limelight_conceal_guifg
        elseif empty(fg) || empty(bg)
            throw s:unsupported()
        else
            let coeff = s:coeff(a:coeff)
            let fg_rgb = s:hex2rgb(fg)
            let bg_rgb = s:hex2rgb(bg)
            let dim_rgb = [
                \ bg_rgb[0] * coeff + fg_rgb[0] * (1 - coeff),
                \ bg_rgb[1] * coeff + fg_rgb[1] * (1 - coeff),
                \ bg_rgb[2] * coeff + fg_rgb[2] * (1 - coeff),
                \ ]
            let dim = '#' .. map(dim_rgb, 'float2nr(v:val)->printf("%x")')->join('')
        endif
        exe printf('hi LimelightDim guifg=%s guisp=bg', dim)
    elseif &t_Co == 256
        if a:coeff < 0 && exists('g:limelight_conceal_ctermfg')
            let dim = g:limelight_conceal_ctermfg
        elseif fg <= -1 || bg <= -1
            throw s:unsupported()
        else
            let coeff = s:coeff(a:coeff)
            let fg = s:gray_contiguous(fg)
            let bg = s:gray_contiguous(bg)
            let dim = float2nr(bg * coeff + fg * (1 - coeff))->s:gray_ansi()
        endif
        if type(dim) == v:t_string
            exe printf('hi LimelightDim ctermfg=%s', dim)
        else
            exe printf('hi LimelightDim ctermfg=%d', dim)
        endif
    else
        throw 'Unsupported terminal.  Sorry.'
    endif
endfu

fu s:error(msg) abort
    echohl ErrorMsg
    echo a:msg
    echohl None
endfu

fu s:parse_coeff(coeff) abort
    let t = type(a:coeff)
    if t == 1
        if a:coeff =~ '^ *[0-9.]\+ *$'
            let c = str2float(a:coeff)
        else
            throw s:invalid_coefficient
        endif
    elseif index([0, 5], t) >= 0
        let c = t
    else
        throw s:invalid_coefficient
    endif
    return c
endfu

fu s:on(range, ...) abort
    try
        let s:limelight_coeff = a:0 > 0 ? s:parse_coeff(a:1) : -1
        call s:dim(s:limelight_coeff)
    catch
        return s:error(v:exception)
    endtry

    let w:limelight_range = a:range
    if !empty(a:range)
        call s:clear_hl()
        call call('s:hl', a:range)
    endif

    augroup limelight
        let was_on = exists('#limelight#CursorMoved')
        au!
        if empty(a:range) || was_on
            au CursorMoved,CursorMovedI * call s:limelight()
        endif
        au ColorScheme * try
            \ |     call s:dim(s:limelight_coeff)
            \ | catch
            \ |     call s:off()
            \ |     throw v:exception
            \ | endtry
    augroup END

    " FIXME: We cannot safely remove this group once Limelight started
    augroup limelight_cleanup | au!
        au WinEnter * call s:cleanup()
    augroup END

    if exists('#CursorMoved')
        do <nomodeline> CursorMoved
    endif
endfu

fu s:off() abort
    call s:clear_hl()
    augroup limelight
        au!
    augroup END
    augroup! limelight
    unlet! w:limelight_prev w:limelight_match_ids w:limelight_range
endfu

fu s:is_on() abort
    return exists('#limelight')
endfu

fu s:cleanup() abort
    if !s:is_on()
        call s:clear_hl()
    end
endfu

fu limelight#execute(bang, visual, line1, line2, ...) abort
    let range = a:visual ? [a:line1, a:line2] : []
    if a:bang
        if a:0 > 0 && a:1 =~ '^!' && !s:is_on()
            if len(a:1) > 1
                call s:on(range, a:1[1:-1])
            else
                call s:on(range)
            endif
        else
            call s:off()
        endif
    elseif a:0 > 0
        call s:on(range, a:1)
    else
        call s:on(range)
    endif
endfu

fu limelight#operator(...) abort
    if !a:0
        let &opfunc = 'limelight#operator'
        return 'g@'
    endif
    call limelight#execute(0, 1, line("'["), line("']"))
endfu
