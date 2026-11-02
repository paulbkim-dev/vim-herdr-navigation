let s:repo = $HERDR_NAV_TEST_REPO
let s:log = $HERDR_NAV_TEST_LOG

execute 'source ' . fnameescape(s:repo . '/editor/vim.vim')

for s:key in ['<C-h>', '<C-j>', '<C-k>', '<C-l>']
  let s:mapping = maparg(s:key, 'n', 0, 1)
  call assert_false(empty(s:mapping), s:key . ' must have a normal-mode mapping')
endfor

let s:left = maparg('<C-h>', 'n', 0, 1)
let s:script = '<SNR>' . s:left.sid . '_'

vsplit
wincmd l
let s:right = win_getid()
execute 'call ' . s:script . "Navigate('h', 'left')"
call assert_notequal(s:right, win_getid(), 'Ctrl+h must move inside Vim first')
call assert_false(filereadable(s:log), 'internal split movement must not call Herdr')

only
execute 'call ' . s:script . "Navigate('l', 'right')"
call assert_true(filereadable(s:log), 'edge navigation must call Herdr')
let s:lines = readfile(s:log)
call assert_equal(1, len(s:lines), 'edge navigation must make one Herdr call')
let s:expected = empty($HERDR_NAV_TEST_EXPECT)
      \ ? 'pane focus --direction right --pane w-test:p1' : $HERDR_NAV_TEST_EXPECT
call assert_equal(
      \ s:expected,
      \ s:lines[0],
      \ 'Vim must target its invoking Herdr pane')

if !empty(v:errors)
  for s:error in v:errors
    echoerr s:error
  endfor
  cquit 1
endif

quitall!
