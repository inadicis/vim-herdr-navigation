" vim-herdr-navigation — Vim side
"
" Maps <C-h/j/k/l> to move between Vim splits. When there is no split in the
" requested direction (Vim is at an edge), hand off to herdr so focus crosses
" into the neighbouring herdr pane.
"
" Fork (inadicis): at pane edge with no neighbor, cycles to next/prev workspace.
"
" Load it from your vimrc, e.g.:
"   source /path/to/vim-herdr-navigation/editor/vim.vim
"
" Only active inside a herdr pane (guards on $HERDR_PANE_ID).

if empty($HERDR_PANE_ID)
  finish
endif

function! s:HerdrCycleWorkspace(dir) abort
  if a:dir !=# 'up' && a:dir !=# 'down' | return | endif
  let l:herdr = empty($HERDR_BIN_PATH) ? 'herdr' : $HERDR_BIN_PATH
  let l:offset = a:dir ==# 'up' ? -1 : 1
  let l:raw = system(shellescape(l:herdr) . ' workspace list')
  try
    let l:decoded = json_decode(l:raw)
    let l:workspaces = l:decoded['result']['workspaces']
    let l:focused_num = 0
    let l:by_number = {}
    for l:ws in l:workspaces
      let l:by_number[l:ws['number']] = l:ws['workspace_id']
      if get(l:ws, 'focused', v:false)
        let l:focused_num = l:ws['number']
      endif
    endfor
    if l:focused_num == 0 | return | endif
    let l:target_id = get(l:by_number, l:focused_num + l:offset, v:null)
    if l:target_id isnot v:null
      call system(shellescape(l:herdr) . ' workspace focus ' . shellescape(l:target_id))
    endif
  catch
  endtry
endfunction

function! s:HerdrFocus(dir) abort
  let l:herdr = empty($HERDR_BIN_PATH) ? 'herdr' : $HERDR_BIN_PATH
  let l:raw = system(shellescape(l:herdr) . ' pane focus --direction ' . a:dir . ' --current')
  try
    let l:decoded = json_decode(l:raw)
    if type(l:decoded) == v:t_dict && has_key(l:decoded, 'result')
      let l:focus = l:decoded['result']['focus']
      if get(l:focus, 'changed', v:true) == v:false
        call s:HerdrCycleWorkspace(a:dir)
      endif
    endif
  catch
  endtry
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
