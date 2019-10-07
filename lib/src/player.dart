part of 'youtube_player.dart';

class _Player extends StatefulWidget {
  final YoutubePlayerController controller;
  final YoutubePlayerFlags flags;

  _Player({
    this.controller,
    this.flags,
  });

  @override
  __PlayerState createState() => __PlayerState();
}

class __PlayerState extends State<_Player> with WidgetsBindingObserver {
  Completer<WebViewController> _webController = Completer<WebViewController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.controller?.play();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.suspending:
        widget.controller?.pause();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: WebView(
        initialUrl: Uri.dataFromString(player, mimeType: 'text/html', encoding: Encoding.getByName('utf-8')).toString(),
        javascriptMode: JavascriptMode.unrestricted,
        initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,
        javascriptChannels: {
          JavascriptChannel(
            name: 'Ready',
            onMessageReceived: (JavascriptMessage message) {
              widget.controller.value =
                  widget.controller.value.copyWith(isReady: true);
            },
          ),
          JavascriptChannel(
            name: 'StateChange',
            onMessageReceived: (JavascriptMessage message) {
              switch (message.message) {
                case '-1':
                  widget.controller.value = widget.controller.value.copyWith(
                      playerState: PlayerState.UN_STARTED, isLoaded: true);
                  break;
                case '0':
                  widget.controller.value = widget.controller.value
                      .copyWith(playerState: PlayerState.ENDED);
                  break;
                case '1':
                  widget.controller.value = widget.controller.value.copyWith(
                    playerState: PlayerState.PLAYING,
                    isPlaying: true,
                    hasPlayed: true,
                    errorCode: 0,
                  );
                  break;
                case '2':
                  widget.controller.value = widget.controller.value.copyWith(
                    playerState: PlayerState.PAUSED,
                    isPlaying: false,
                  );
                  break;
                case '3':
                  widget.controller.value = widget.controller.value
                      .copyWith(playerState: PlayerState.BUFFERING);
                  break;
                case '5':
                  widget.controller.value = widget.controller.value
                      .copyWith(playerState: PlayerState.CUED);
                  break;
                default:
                  throw Exception("Invalid player state obtained.");
              }
            },
          ),
          JavascriptChannel(
            name: 'PlaybackQualityChange',
            onMessageReceived: (JavascriptMessage message) {
              print("PlaybackQualityChange ${message.message}");
            },
          ),
          JavascriptChannel(
            name: 'PlaybackRateChange',
            onMessageReceived: (JavascriptMessage message) {
              switch (message.message) {
                case '2':
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.DOUBLE);
                  break;
                case '1.5':
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.ONE_AND_A_HALF);
                  break;
                case '1':
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.NORMAL);
                  break;
                case '0.5':
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.HALF);
                  break;
                case '0.25':
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.QUARTER);
                  break;
                default:
                  widget.controller.value = widget.controller.value
                      .copyWith(playbackRate: PlaybackRate.NORMAL);
              }
            },
          ),
          JavascriptChannel(
            name: 'Errors',
            onMessageReceived: (JavascriptMessage message) {
              widget.controller.value = widget.controller.value
                  .copyWith(errorCode: int.tryParse(message.message) ?? 0);
            },
          ),
          JavascriptChannel(
            name: 'VideoData',
            onMessageReceived: (JavascriptMessage message) {
              var videoData = jsonDecode(message.message);
              double duration = videoData['duration'] * 1000;
              print("VideoData ${message.message}");
              widget.controller.value = widget.controller.value.copyWith(
                duration: Duration(
                  milliseconds: duration.floor(),
                ),
              );
            },
          ),
          JavascriptChannel(
            name: 'CurrentTime',
            onMessageReceived: (JavascriptMessage message) {
              double position = (double.tryParse(message.message) ?? 0) * 1000;
              widget.controller.value = widget.controller.value.copyWith(
                position: Duration(
                  milliseconds: position.floor(),
                ),
              );
            },
          ),
          JavascriptChannel(
            name: 'LoadedFraction',
            onMessageReceived: (JavascriptMessage message) {
              widget.controller.value = widget.controller.value.copyWith(
                buffered: double.tryParse(message.message) ?? 0,
              );
            },
          ),
        },
        onWebViewCreated: (webController) {
          _webController.complete(webController);
          _webController.future.then(
            (controller) {
              widget.controller.value = widget.controller.value
                  .copyWith(webViewController: webController);
            },
          );
        },
        onPageFinished: (_) {
          widget.controller.value = widget.controller.value.copyWith(
            isEvaluationReady: true,
          );
          if (Platform.isAndroid && widget.flags.forceHideAnnotation) {
            widget.controller.forceHideAnnotation();
          }
        },
      ),
    );
  }

  String get player {
    if (Platform.isAndroid) {
      return androidYoutubeIframePlayer;
    } else if (Platform.isIOS) {
      return iosYoutubeIframePlayer;
    } else {
      return 'https://flutter.io';
    }
  }

  String get androidYoutubeIframePlayer {
    return 
    '''
<!DOCTYPE html>
<html>
  <head>
    <style>
      html, body {
        height: 100%;
        width: 100%;
        margin: 0;
        padding: 0;
        background-color: #000000;
        overflow: hidden;
        position: fixed;
      }
    </style>
    <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
  </head>

  <body>
    <!-- 1. The <iframe> (and video player) will replace this <div> tag. -->
    <div id="player"></div>

    <script>
      // 2. This code loads the IFrame Player API code asynchronously.
      var tag = document.createElement('script');

      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
    </script>

    <script type="text/javascript">
      var player;
      var timerId;
      function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
              height: '100%',
              width: '100%',
              host: 'https://www.youtube.com',
              playerVars: {
                  'controls': 0,
                  'autoplay': 0,
                  'playsinline': 1,
                  'enablejsapi': 1,
                  'fs': 0,
                  'rel': 0,
                  'showinfo': 0,
                  'iv_load_policy': 3,
                  'modestbranding': 1,
                  'cc_load_policy': 0,
              },
              events: {
                  onReady: function (event) { Ready.postMessage("Ready") },
                  onStateChange: function (event) { sendPlayerStateChange(event.data) },
                  onPlaybackQualityChange: function (event) { PlaybackQualityChange.postMessage(event.data) },
                  onPlaybackRateChange: function (event) { PlaybackRateChange.postMessage(event.data) },
                  onError: function (error) { Errors.postMessage(error.data) }
              },
          });
      }

      function hideAnnotations() {
          document.body.style.height = '1000%';
          document.body.style.width = '1000%';
          document.body.style.transform = 'scale(0.1)';
          document.body.style.transformOrigin = 'left top';
          document.documentElement.style.height = '1000%';
          document.documentElement.style.width = '1000%';
          document.documentElement.style.transform = 'scale(0.1)';
          document.documentElement.style.transformOrigin = 'left top';
      }

      function sendPlayerStateChange(playerState) {
          clearTimeout(timerId);
          StateChange.postMessage(playerState);
          if (playerState == 1) {
              startSendCurrentTimeInterval();
              sendVideoData(player);
          }
      }

      function sendVideoData(player) {
          var videoData = {
              'duration': player.getDuration(),
              'videoUrl': player.getVideoUrl(),
              'availableQualityLevels': player.getAvailableQualityLevels(),
              'videoEmbedCode': player.getVideoEmbedCode(),
          };
          VideoData.postMessage(JSON.stringify(videoData));
      }

      function startSendCurrentTimeInterval() {
          timerId = setInterval(function () {
              CurrentTime.postMessage(player.getCurrentTime());
              LoadedFraction.postMessage(player.getVideoLoadedFraction());
          }, 100);
      }

      function play() {
          player.playVideo();
          return '';
      }

      function pause() {
          player.pauseVideo();
          return '';
      }

      function loadById(id, startAt) {
          player.loadVideoById(id, startAt);
          return '';
      }

      function cueById(id, startAt) {
          player.cueVideoById(id, startAt);
          return '';
      }

      function mute() {
          player.mute();
          return '';
      }

      function unMute() {
          player.unMute();
          return '';
      }

      function setVolume(volume) {
          player.setVolume(volume);
          return '';
      }

      function seekTo(position, seekAhead) {
          player.seekTo(position, seekAhead);
          return '';
      }

      function setSize(width, height) {
          player.setSize(width, height);
          return '';
      }

      function setPlaybackRate(rate) {
          player.setPlaybackRate(rate);
          return '';
      }
    </script>
  </body>
</html>
    ''';
  }
  
  String get iosYoutubeIframePlayer {
    return 
    '''
<!DOCTYPE html>
<html>
  <head>
    <style>
      html, body {
        height: 100%;
        width: 100%;
        margin: 0;
        padding: 0;
        background-color: #000000;
        overflow: hidden;
        position: fixed;
      }
    </style>
    <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
  </head>

  <body>
    <!-- 1. The <iframe> (and video player) will replace this <div> tag. -->
    <div id="player"></div>

    <script>
      // 2. This code loads the IFrame Player API code asynchronously.
      var tag = document.createElement('script');

      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
    </script>

    <script type="text/javascript">
      var player;
      var timerId;
      function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
              height: '100%',
              width: '100%',
              host: 'https://www.youtube.com',
              playerVars: {
                  'controls': 0,
                  'autoplay': 0,
                  'playsinline': 1,
                  'enablejsapi': 1,
                  'fs': 0,
                  'rel': 0,
                  'showinfo': 0,
                  'iv_load_policy': 3,
                  'modestbranding': 1,
                  'cc_load_policy': 0,
              },
              events: {
                  onReady: function (event) { Ready.postMessage("Ready") },
                  onStateChange: function (event) { sendPlayerStateChange(event.data) },
                  onPlaybackQualityChange: function (event) { PlaybackQualityChange.postMessage(event.data) },
                  onPlaybackRateChange: function (event) { PlaybackRateChange.postMessage(event.data) },
                  onError: function (error) { Errors.postMessage(error.data) }
              },
          });
      }

      function sendPlayerStateChange(playerState) {
          clearTimeout(timerId);
          StateChange.postMessage(playerState);
          if (playerState == 1) {
              startSendCurrentTimeInterval();
              sendVideoData(player);
          }
      }

      function sendVideoData(player) {
          var videoData = {
              'duration': player.getDuration(),
              'videoUrl': player.getVideoUrl(),
              'availableQualityLevels': player.getAvailableQualityLevels(),
              'videoEmbedCode': player.getVideoEmbedCode(),
          };
          VideoData.postMessage(JSON.stringify(videoData));
      }

      function startSendCurrentTimeInterval() {
          timerId = setInterval(function () {
              CurrentTime.postMessage(player.getCurrentTime());
              LoadedFraction.postMessage(player.getVideoLoadedFraction());
          }, 100);
      }

      function play() {
          player.playVideo();
          return '';
      }

      function pause() {
          player.pauseVideo();
          return '';
      }

      function loadById(id, startAt) {
          player.loadVideoById(id, startAt);
          return '';
      }

      function cueById(id, startAt) {
          player.cueVideoById(id, startAt);
          return '';
      }

      function mute() {
          player.mute();
          return '';
      }

      function unMute() {
          player.unMute();
          return '';
      }

      function setVolume(volume) {
          player.setVolume(volume);
          return '';
      }

      function seekTo(position, seekAhead) {
          player.seekTo(position, seekAhead);
          return '';
      }

      function setSize(width, height) {
          player.setSize(width, height);
          return '';
      }

      function setPlaybackRate(rate) {
          player.setPlaybackRate(rate);
          return '';
      }
    </script>
  </body>
</html>
    ''';
  }
}
