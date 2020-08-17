import 'package:intl/intl.dart';
import 'package:sickchill/sickchill.dart';

main() async {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final api = SickChill(apiKey: 'MyAPIKeyHere', baseUrl: 'http://192.168.1.35:8081/', enableLogs: true);
  final shows = await api.getShows();
  for (var i = 0; i < shows.length; i++) {
    print(shows[i].name + ' ' + shows[i].nextEpisodeStr);
  }
  final seasons = await api.getSeasons(shows.first.id);
  print(seasons);
  //api.setEpisodeStatus(showId: shows.first.id, status: TvShowEpisodeStatus.ignored, seasonNumber: "1", episodeNumber: "1");
  print(await api.searchShow('moon knight'));
}
