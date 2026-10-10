" vim-herdr-navigation — Vim side
"
" Maps <C-h/j/k/l> to move between Vim splits. When there is no split in the
" requested direction (Vim is at an edge), hand off to herdr so focus crosses
" into the neighbouring herdr pane.
"
" Load it from your vimrc, e.g.:
"   source /path/to/vim-herdr-navigation/editor/vim.vim
"
" Only active inside a herdr pane (guards on $HERDR_PANE_ID).

if empty($HERDR_PANE_ID)
  finish
endif

" navigate.sh, if this file still sits next to it in a plugin checkout. Going
" through it means crossing out of Vim behaves like crossing out of any other
" pane (edge spillover and all). Copied somewhere else, we just move focus.
let s:navigate = expand('<sfile>:p:h:h') . '/navigate.sh'

function! s:HerdrFocus(dir) abort
  if filereadable(s:navigate)
    call system('bash ' . shellescape(s:navigate) . ' --no-detect ' . a:dir)
    return
  endif
  let l:herdr = empty($HERDR_BIN_PATH) ? 'herdr' : $HERDR_BIN_PATH
  " Target this pane explicitly: --current resolves to the server's globally
  " focused pane, which is not necessarily the Vim instance making the call.
  call system(shellescape(l:herdr)
        \ . ' pane focus --direction ' . shellescape(a:dir)
        \ . ' --pane ' . shellescape($HERDR_PANE_ID))
endfunction

function! s:Navigate(wincmd, dir) abort
  let l:prev = winnr()
  execute 'wincmd ' . a:wincmd
  if winnr() == l:prev
    " No Vim window that way: cross into the herdr pane.
    call s:HerdrFocus(a:dir)
  endif
endfunction

nnoremap <silent> <C-h> :call <SID>Navigate('h', 'left')<CR>
nnoremap <silent> <C-j> :call <SID>Navigate('j', 'down')<CR>
nnoremap <silent> <C-k> :call <SID>Navigate('k', 'up')<CR>
nnoremap <silent> <C-l> :call <SID>Navigate('l', 'right')<CR>
