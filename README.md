# blog
Git for my blog!

The Blog is configured behind Nginx.

Simply import the td4b folder into /home/ubuntu and then build the website via:
```
hugo --baseURL https://twestdev.com
```
The resulting /public folder can be coped over to the nginx site.
```
mv /public /var/www/.
```
Note: You can check out the nginx config here:
```
/etc/nginx/conf.d
```
The TLS was configured with letsEncrypt.
