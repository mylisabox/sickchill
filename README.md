# sickchill

Dart package to manage remote sickchill instance, for Flutter support with UI widgets please check [flutter_sickchill](https://github.com/mylisabox/flutter_sickchill)

## Getting Started

Create an instance of `SickChill`, you can then use it in any data state management you want (bloc, provider, mobx...)

```dart
final sickChill = SickChill(
  baseUrl: 'http://192.168.1.35:8081',
  apiKey: 'MyApiKey',//can be found on settings in web interface
  enableLogs: true,
);
``` 

By default baseUrl uses `http://localhost:8081`.

Once you have that you can simply interact with sickchill's data.

## Simple examples

### Getting shows

```dart
final shows = await sickChill.getShows();
print(shows);
``` 

### Getting show details

```dart
final show = await sickChill.getShowDetails(shows.first.id);
print(show);
``` 

### Searching and adding a show 

```dart
final results = await sickChill.searchShow('Friends')
await sickChill.addShow(indexerId: results.first.id);
``` 

### Remove show

```dart
await transmission.removeShow(tvShow.id, removeFiles: true);
``` 

### Basic show actions

With the show id you can use the methods `getSeasons`, `pauseShow`, `refreshShowFromDisk` and `forceFullUpdateShow` 
