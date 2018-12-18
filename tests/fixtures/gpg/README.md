== public/private key pairs for test keys

* user1 and user2 are normal gpg key sets for user1@gitsecret.io and 
  user2@gitsecret.io. They have the passphrases 'user1pass' and 'user2pass', 
  respectively.

* user3 was created by `gpg --quick-generate user3@gitsecret.io` 
  and therefore has only an email associated with it (no username).  
  It has the passphrase 'user3pass' as the tests expect.
  This user was created to fix https://github.com/sobolevn/git-secret/issues/227 ,
  "keys with no info but the email address not recognized by whoknows"

* user4 is an expired keypair that was created with `gpg --gen-key`, 
  using the name 'user4' and the email address user4@gitsecret.io. 
  As the tests expect, it has the passphrase 'user4pass'.  

  It is set to expire on 2018-09-23. To make keys expire, I used the 
  `gpg --edit-key user@email` command's `expiry` function.

  The public and private key for user4 were exported with

    `gpg --export --armor user4@gitsecret.io > tests/fixtures/gpg/user4@gitsecret.io/public.key`

  and

    `gpg --export-secret-keys --armor user4@gitsecret.io > tests/fixtures/gpg/user4@gitsecret.io/private.key`

* user5 is for testing revoked certifates, and has a revocation certificate 
  used in the tests to revoke the certificate.

The revocation certificate was created with 	

    `gpg --gen-revoke {FINGERPRINT}`

and is stored at 

    tests/fixtures/gpg/user5@gitsecret.io/revocation-cert.txt

You can also see it has been recorded as revoked at 

https://pgp.mit.edu/pks/lookup?search=user5%40gitsecret.io&op=vindex

