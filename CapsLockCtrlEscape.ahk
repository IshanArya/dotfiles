#Requires AutoHotkey v2.0+

*CapsLock::Send('{Ctrl Down}')

*CapsLock Up:: {
    prior := A_PriorKey
    Send('{Ctrl Up}')
    If InStr(prior, 'CapsLock')
        Send('{Escape}')
}

*RCtrl::CapsLock