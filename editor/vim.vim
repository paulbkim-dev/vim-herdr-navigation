" vim-herdr-navigation — Vim side
"
" Maps <C-h/j/k/l> to move between Vim splits. When there is no split in the
" requested direction (Vim is at an edge), hand off to herdr so focus crosses
" into the neighbouring herdr pane.
"
" <C-h/j/k/l> is only the default: g:herdr_nav_keys swaps any direction's
" key, and g:herdr_nav_no_mappings plus the <Plug>(HerdrNavigate*) mappings
" allow any binding at all. See the mapping section at the bottom.
"
" Load it from your vimrc, e.g.:
"   source /path/to/vim-herdr-navigation/editor/vim.vim
"
" Only active inside a herdr pane (guards on $HERDR_PANE_ID).

if empty($HERDR_PANE_ID)
  finish
endif

function! s:HerdrFocus(dir) abort
  let l:herdr = empty($HERDR_BIN_PATH) ? 'herdr' : $HERDR_BIN_PATH
  call system(shellescape(l:herdr) . ' pane focus --direction ' . a:dir . ' --current')
endfunction

function! s:Navigate(wincmd, dir) abort
  let l:prev = winnr()
  execute 'wincmd ' . a:wincmd
  if winnr() == l:prev
    " No Vim window that way: cross into the herdr pane.
    call s:HerdrFocus(a:dir)
  endif
endfunction

" <Plug> mappings, one per direction, so any key can drive the navigation.
nnoremap <silent> <Plug>(HerdrNavigateLeft)  :call <SID>Navigate('h', 'left')<CR>
nnoremap <silent> <Plug>(HerdrNavigateDown)  :call <SID>Navigate('j', 'down')<CR>
nnoremap <silent> <Plug>(HerdrNavigateUp)    :call <SID>Navigate('k', 'up')<CR>
nnoremap <silent> <Plug>(HerdrNavigateRight) :call <SID>Navigate('l', 'right')<CR>

" Default keys: <C-h/j/k/l>. Two ways to change them (set before this file
" loads), both mirrored on the herdr side by HERDR_NAV_KEY_LEFT/DOWN/UP/RIGHT
" (see "Custom keys" in the README):
"   g:herdr_nav_keys           replace any subset of the defaults, e.g.
"                              {'left': '<C-Left>', 'right': '<C-Right>'};
"                              an empty string drops that direction
"   g:herdr_nav_no_mappings    set to 1 to define no keys at all; bind the
"                              <Plug> mappings above yourself
if !get(g:, 'herdr_nav_no_mappings', 0)
  let s:plug = {
        \ 'left': '<Plug>(HerdrNavigateLeft)',
        \ 'down': '<Plug>(HerdrNavigateDown)',
        \ 'up': '<Plug>(HerdrNavigateUp)',
        \ 'right': '<Plug>(HerdrNavigateRight)',
        \ }
  let s:keys = extend(
        \ {'left': '<C-h>', 'down': '<C-j>', 'up': '<C-k>', 'right': '<C-l>'},
        \ get(g:, 'herdr_nav_keys', {}))
  for [s:dir, s:lhs] in items(s:keys)
    if has_key(s:plug, s:dir) && !empty(s:lhs)
      execute 'nmap <silent> ' . s:lhs . ' ' . s:plug[s:dir]
    endif
  endfor
endif
