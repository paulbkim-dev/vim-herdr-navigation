" vim-herdr-navigation — Vim side
"
" Maps <C-h/j/k/l> to move between Vim splits. When there is no split in the
" requested direction (Vim is at an edge), hand off to herdr so focus crosses
" into the neighbouring herdr pane.
"
" Load it from your vimrc, e.g.:
"   source /path/to/vim-herdr-navigation/editor/vim.vim
"
" Only active inside a herdr pane: $HERDR_PANE_ID in the herdr TUI, or
" $HC_TERMINAL_ID in the Herdr desktop app.

if empty($HERDR_PANE_ID) && empty($HC_TERMINAL_ID)
  finish
endif

function! s:HerdrFocus(dir) abort
  if empty($HERDR_PANE_ID)
    call system('herdr-app do pane.go --direction ' . shellescape(a:dir))
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
