" ftdetect/peoplecode.vim
" Recognize files produced by DecodePeopleCode / AppRefiner / App Designer exports,
" as well as the extensions used by the old PeopleSoftTools VSCode extension.
au BufRead,BufNewFile *.pcode setfiletype peoplecode
au BufRead,BufNewFile *.ppl   setfiletype peoplecode

" DecodePeopleCode dumps each PeopleCode program as plain .txt inside a folder
" hierarchy that mirrors the App Designer project tree, e.g.:
"   RECORD.PSCAMA.FieldFormula.OPRID.txt
"   AAAA_APP_PKG.MyPackage.MyClass.OnExecute.txt
" We only claim files that live under a folder literally named PeopleCode,
" or whose filename looks like a PeopleCode event name, so we don't hijack
" every random .txt file in the project.
au BufRead,BufNewFile */PeopleCode/*.txt setfiletype peoplecode
au BufRead,BufNewFile *.FieldFormula.*.txt   setfiletype peoplecode
au BufRead,BufNewFile *.FieldEdit.*.txt      setfiletype peoplecode
au BufRead,BufNewFile *.FieldDefault.*.txt   setfiletype peoplecode
au BufRead,BufNewFile *.FieldChange.*.txt    setfiletype peoplecode
au BufRead,BufNewFile *.RowInit.*.txt        setfiletype peoplecode
au BufRead,BufNewFile *.RowInsert.*.txt      setfiletype peoplecode
au BufRead,BufNewFile *.RowDelete.*.txt      setfiletype peoplecode
au BufRead,BufNewFile *.RowSelect.*.txt      setfiletype peoplecode
au BufRead,BufNewFile *.SaveEdit.*.txt       setfiletype peoplecode
au BufRead,BufNewFile *.SavePreChange.*.txt  setfiletype peoplecode
au BufRead,BufNewFile *.SavePostChange.*.txt setfiletype peoplecode
au BufRead,BufNewFile *.OnExecute.*.txt      setfiletype peoplecode
au BufRead,BufNewFile *.Workflow.*.txt       setfiletype peoplecode

" Fallback: content-based sniff for the handful of files that don't match a
" naming convention above (e.g. you renamed something). Only fires for .txt
" since we don't want to steal other filetypes.
function! s:DetectPeopleCode()
  if getline(1) =~? '^\s*import\s\+\S\+\s*:\s*\S\+\s*;' || getline(1) =~? '^\s*\(class\|interface\)\s\+\w\+'
    setfiletype peoplecode
    return
  endif
  " scan first ~40 lines for unmistakable PeopleCode idioms
  let l:n = min([40, line('$')])
  for l:i in range(1, l:n)
    if getline(l:i) =~? '\<end-class\>\|\<end-method\>\|\<end-function\>\|&\a\w*\s*=\s*CreateRecord\|Declare\s\+Function\s\+\w\+\s\+PeopleCode'
      setfiletype peoplecode
      return
    endif
  endfor
endfunction

au BufRead,BufNewFile *.txt call s:DetectPeopleCode()
