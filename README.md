# phpmyadmin-curl-export

REQUIREMENTS
---------------------------
* curl
* coreutils
* grep

USAGE
---------------------------
Simple usage
````
phpmyadmin-curl-export --auth-type-cookie --dbname-example --phpmyadmin-user-example --phpmyadmin-password-example --host-http://localhost/phpMyAdmin
````

Enable compression
````
phpmyadmin-curl-export --auth-type-cookie --dbname-example --phpmyadmin-user-example --phpmyadmin-password-example --host-http://localhost/phpMyAdmin --compression
````

Add DROP TABLE / VIEW / PROCEDURE / FUNCTION / EVENT / TRIGGER statement
````
phpmyadmin-curl-export --auth-type-cookie --dbname-example --phpmyadmin-user-example --phpmyadmin-password-example --host-http://localhost/phpMyAdmin --add-drop
````
