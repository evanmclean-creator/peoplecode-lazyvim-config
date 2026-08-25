" ftplugin/peoplecode.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal commentstring=REM\ %s;
setlocal comments=sr:/*,mb:*,ex:*/,:REM

" '&' and '%' are meaningful identifier-start characters in PeopleCode
" (&UserVariable, %SystemVariable) - treat them as keyword chars so that
" *, gd, ciw, etc. operate on the whole variable name instead of stopping
" at the sigil.
setlocal iskeyword+=&,%

" tabs: App Designer's own editor traditionally uses hard tabs; adjust to
" taste, this is just a sane default.
setlocal tabstop=4 shiftwidth=4 expandtab

" matchit / vim-matchup support for %, if either is installed
if exists("loaded_matchit") || exists("g:loaded_matchup")
  let b:match_ignorecase = 1
  let b:match_words =
    \ '\<if\>:\<then\>:\<else\>:\<end-if\>,' .
    \ '\<for\>:\<end-for\>,' .
    \ '\<while\>:\<end-while\>,' .
    \ '\<repeat\>:\<until\>,' .
    \ '\<evaluate\>:\<when\%(-other\)\=\>:\<end-evaluate\>,' .
    \ '\<try\>:\<catch\>:\<end-try\>,' .
    \ '\<class\>:\<end-class\>,' .
    \ '\<interface\>:\<end-interface\>,' .
    \ '\<method\>:\<end-method\>,' .
    \ '\<function\>:\<end-function\>,' .
    \ '\<get\>:\<end-get\>,' .
    \ '\<set\>:\<end-set\>'
endif

let b:undo_ftplugin = "setlocal commentstring< comments< iskeyword< tabstop< shiftwidth< expandtab<"

let &cpo = s:cpo_save
unlet s:cpo_save
