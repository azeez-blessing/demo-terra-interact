ssh-keygen -t rsa -b 4020 -N "abp" -f "./key/prokey"
 -N = new passphrase
 4 = r
 2 = w
 1 = x
 644 = rw-r--r---
 755 = rwxr-xr-x
 723 = rwx-w-r-x
 700 = rwx------
 744 = rwxr--r---
 644 = rw-r--r--- folder
 755 = rwxr-xr-x
 
 git config --local --add core.sshcommand "ssh -i D:/prog/terra/env-proj/key/prokey"
 git remote add terra-remote-url git@github.com:azeez-blessing/demo-terra-interact.git