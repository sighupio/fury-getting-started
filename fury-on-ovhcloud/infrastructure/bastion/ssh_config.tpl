Host bastion_apps
    HostName bastionIP
    User ubuntu
    ForwardAgent yes
    IdentityFile ~/.ssh/id_rsa
