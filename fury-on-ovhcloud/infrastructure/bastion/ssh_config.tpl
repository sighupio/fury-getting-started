Host bastion_apps
    HostName bastionIP
    User ubuntu
    ForwardAgent yes
    IdentityFile ../sshKeypair/TF_VAR_keypairName
