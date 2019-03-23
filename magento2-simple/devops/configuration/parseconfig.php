<?php 
class ConfigParser 
{

	public $setupConfigurations = [];
	public $forceConfigurations = [];

	function parseVariables() {
		foreach ($_ENV as $envVar => $value) {
			$path = explode('__',strtolower($envVar));
			$namespace = array_shift($path);
			$type = array_shift($path);
			$scope = array_shift($path);
			$scopeId = '0';
			if ($scope !== 'default') {
				$scopeId = array_shift($path);
			}
			if ($namespace === 'setup' && $type === 'config') {
				$this->setupConfigurations[] = array(
					'scope' => $scope,
					'scope_id' => $scopeId,
					'path' => implode('/',$path),
					'value' => $value
				);
			}
			if ($namespace === 'force' && $type === 'config') {
				$this->forceConfigurations[] = array(
					'scope' => $scope,
					'scope_id' => $scopeId,
					'path' => implode('/',$path),
					'value' => $value
				);
			}
		}
	}

	function storeConfigurations() {
		$mysqli = new mysqli(
			$_ENV['MAGENTO_DB_HOST'], 
			$_ENV['MAGENTO_DB_USER'], 
			$_ENV['MAGENTO_DB_PASSWORD'], 
			$_ENV['MAGENTO_DB_NAME']
		);

		/* check connection */
		if (mysqli_connect_errno()) {
		    printf("Connect failed: %s\n", mysqli_connect_error());
		    exit();
		}

		foreach ($this->setupConfigurations as $config) {
			list( $scope, $scopeId, $path, $value) = array_values($config);
			/* create a prepared statement */
			$stmt =  $mysqli->stmt_init();
			if (
				$stmt->prepare("INSERT IGNORE INTO `core_config_data` (`scope`, `scope_id`, `path`, `value`) VALUE (?, ?, ?, ?);")
			) {

			    /* bind parameters for markers */
			    $stmt->bind_param("ssss", $scope, $scopeId, $path, $value);

			    /* execute query */
			    $stmt->execute();

			    /* close statement */
			    $stmt->close();
			}
		}

		foreach ($this->forceConfigurations as $config) {
			list( $scope, $scopeId, $path, $value) = array_values($config);
			/* create a prepared statement */
			$stmt =  $mysqli->stmt_init();
			if (
				$stmt->prepare("INSERT INTO `core_config_data` (`scope`, `scope_id`, `path`, `value`) VALUE (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `scope` = ?, `scope_id` = ?, `path` = ?, `value` = ?;")
			) {

			    /* bind parameters for markers */
			    $stmt->bind_param("ssssssss", $scope, $scopeId, $path, $value, $scope, $scopeId, $path, $value);

			    /* execute query */
			    $stmt->execute();

			    /* close statement */
			    $stmt->close();
			}
		}

		/* close connection */
		$mysqli->close();
	}

	function run() {
		$this->parseVariables();
		$this->storeConfigurations();
	}
}

$configParser = new ConfigParser();

$configParser->run();