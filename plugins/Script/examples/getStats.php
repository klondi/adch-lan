#!/usr/bin/php
<?php
require('CSVParser.php');
$shortOpts = "";
$shortOpts .= "f::";  // Required value
$shortOpts .= "o::"; // Optional value

$longOpts = array(
    "field::",     // Required value
    "output::",    // Optional value
);

$options = getopt($shortOpts, $longOpts);

defaultParams($options, "field", "");
defaultParams($options, "output", "cacti");

$pr = new \DC4Lan\Stats\Parser("/usr/share/adchpp-lan-9999/scripts/FL_DataBase/stats.txt");

$timestamp = $pr->getValue("localtime");

if ($options['field'] != "") {
    $field = $options['field'];
    $value = array_merge($timestamp, $pr->getValue($field));
} else {
    $value = $pr->getAll();
}

if (is_null($value) || is_null($timestamp)) {
    echo "ERR: Invalid field name\n";
    help();
    exit(-1);
}

output($value, $options['output']);
exit(0);

function defaultParams(&$options, $key, $defValue)
{
    if (!isset($options[$key])) {
        $options[$key] = $defValue;
    }
}

function output($data, $type)
{
    switch ($type){
        case "json":
            echo json_encode($data);
            break;
        case "cacti":
        default:
            $output = "";
            if (is_array($data)) {
                foreach ($data as $key => $value) {
                    $output .= " $key:$value";
                }
                $output = trim($output);
                $output .= "\n";
            } else {
                echo "ERR: Invalid data\n";
                exit(-1);
            }
            echo $output;
            break;
    }
}

function help()
{
    echo "Usage: getStats <fieldname>\n";
    echo "  <fieldname> values:\n";

    foreach (\DC4Lan\Stats\StatsFields::getFields() as $field){
        echo "\t" . $field . "\n";
    }

    echo "\n";
}