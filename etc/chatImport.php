<?php
error_reporting(-1);
ini_set('display_errors','1');

exec("cat chatlog.txt | perl words.pl | perl freq.pl", $jsonString);

$array_terms = json_decode($jsonString[0], true);
arsort($array_terms, SORT_ASC);
array_pop($array_terms);
echo (json_encode($array_terms));
