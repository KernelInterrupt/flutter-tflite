import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_detection_ssd_mobilenet/object_detection.dart';
import 'package:image/image.dart' as img;

class Video_utils extends StatefulWidget {
  const Video_utils({super.key});

  @override
  State<Video_utils> createState() => video_utils();
}

class video_utils extends State<Video_utils> {
  final imagePicker = ImagePicker();
  late VideoPlayerController controller;
  late File videoFile;
  String? videoPath;
  String? videoUrl;
  TextDetection? textDetection;
  ObjectDetection? objectDetection;

  GlobalKey _containerKey = GlobalKey();
  Uint8List? image;

  @override
  void initState() {
    super.initState();
    objectDetection = ObjectDetection();
    textDetection=TextDetection();
    controller = VideoPlayerController.networkUrl(Uri.parse(""));
    controller.initialize().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> selectVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() {
        videoFile = File(result.files.single.path!);
        videoPath = videoFile.path;
        videoUrl = null; // 清空视频URL
      });
      controller.dispose();
      setState(() {});
      controller = VideoPlayerController.file(videoFile);
      controller.initialize().then((_) {
        controller.play();
        setState(() {});
      });
    }
  }

  void playVideoFromUrl() {
    if (videoUrl != null) {
      setState(() {
        videoPath = null; // 清空视频路径
      });
      controller.dispose();
      controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl!));
      controller.initialize().then((_) {
        controller.play();
        setState(() {});
      });
    }
  }

  Widget buildVideoWidget() {
    if (controller.value.isInitialized) {
      return RepaintBoundary(
        key: _containerKey,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      return const Text('No video selected');
    }
  }

  Future<ui.Image> captureImageFromVideo(GlobalKey _containerKey) async {
    RenderRepaintBoundary boundary = _containerKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary;
    ui.Image capturedImage =
        await boundary.toImage(pixelRatio: ui.window.devicePixelRatio);
    return capturedImage;
  }

//ui.Image转Uint8List
  Future<Uint8List> uiImage2Uint8List(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asInt8List();
    final bytesBuffer = bytes.buffer;
    return Uint8List.view(bytesBuffer);
  }
 img.Image drawQuadrilateral(img.Image image,List<List<int>> coordinate)
 {
    // 连接四边形的四个顶点
    for (int i = 0; i < coordinate.length; i++) {
      //x1=coordinate[i][1];
      //y1=coordinate[i][0];
      //x2=coordinate[i][3];
      //y2=coordinate[i][2];
      img.drawLine(image,
            x1: coordinate[i][1],
            y1: coordinate[i][0],
            x2: coordinate[i][3],
            y2: coordinate[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,);
    }
    
  
  return image;

 }
  Uint8List drawResult(Uint8List imageData, ImageAnalysisResult result) {
    final imageTmp = img.decodeImage(imageData);
    final imageForDrawing = imageTmp!;
    String type = result.type;
    List<int> classes = result.classes;
    List<List<double>> locations = result.locations;
    List<String> classication = result.classication;
    List<double> scores = result.scores;
    int numberOfDetections = result.numberOfDetections;
    int originalHeight = result.originalHeight;
    int originalWidth = result.originalWidth;
    int scaledHeight = result.scaledHeight;
    int scaledWidth = result.scaledWidth;
    
      
    for (int i = 0; i < numberOfDetections; i++) {
      for (int j = 0; j < locations[i].length; j++) {
        if (j == 1 || j == 3) {
          // 转换x轴坐标
          locations[i][j] =
              locations[i][j] * originalWidth / scaledWidth;
        } else if (i == 0 && j == 2) {
          // 执行第二行第二列元素的操作
          locations[i][j] =
              locations[i][j] * originalHeight / scaledHeight;
        } else {
          // 其他元素保持不变
        }
      }
    }
    List<List<int>> finalLocations = locations.map((row) {
      return row.map((element) {
        return element.toInt();
      }).toList();
    }).toList();
    if (type == 'Object') {
      for (var i = 0; i < numberOfDetections; i++) {
        if (scores[i] > 0.6) {
          // Rectangle drawing
          img.drawRect(
            imageForDrawing,
            x1: finalLocations[i][1],
            y1: finalLocations[i][0],
            x2: finalLocations[i][3],
            y2: finalLocations[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,
          );

          // Label drawing
          img.drawString(
            imageForDrawing,
            '${classication[i]} ${scores[i]}',
            font: img.arial14,
            x: finalLocations[i][1] + 1,
            y: finalLocations[i][0] + 1,
            color: img.ColorRgb8(255, 0, 0),
          );
        }
      }
    }
    else if(type=='Text')//文字类score在数据后处理时已经根据阈值筛选了，所以这里不需要按照score（置信度）来筛选画图
    {
        for (var i = 0; i < numberOfDetections; i++) {
        
          // Rectangle drawing
          img.drawRect(
            imageForDrawing,
            x1: finalLocations[i][1],
            y1: finalLocations[i][0],
            x2: finalLocations[i][3],
            y2: finalLocations[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,
          );

          
        
      }
    }

    return img.encodePng(imageForDrawing);
  }

//暂时没用，保存截图到某个路径
  Future<void> saveImage(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asInt8List().cast<int>();

    // 指定保存目录的路径
    final directory = Directory('/home/pc/images'); // 将路径替换为想要保存到的目录路径

    if (await directory.exists()) {
      // 生成一个唯一的文件名
      final fileName = 'video_snapshot.png';

      // 创建文件并写入截图数据
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      print('Screenshot saved at: ${file.path}');
    } else {
      print('目录不存在：${directory.path}');
    }
  }

  void PlayVideo() {
    controller.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: (image != null) ? Image.memory(image!) : Container(),
              ),
            ),
            Expanded(
              child: buildVideoWidget(),
            ),
            const SizedBox(),
            if (videoPath == null)
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      videoUrl = value.trim();
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Enter video URL',
                  ),
                ),
              ),
            if (videoPath != null)
              FloatingActionButton(
                onPressed: () {
                  // Wrap the play or pause in a call to `setState`. This ensures the
                  // correct icon is shown.
                  setState(() {
                    // If the video is playing, pause it.
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      // If the video is paused, play it.
                      controller.play();
                    }
                  });
                },
                // Display the correct icon depending on the state of the player.
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () async {
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  
                  Uint8List imageTmp = await uiImage2Uint8List(capturedImage);
                  ImageAnalysisResult result =
                      textDetection!.analyseImageUI(imageTmp);
                  image = drawResult(imageTmp, result);

                  setState(() {});
                },
                child: const Text('Analyze Text'),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () async {
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  saveImage(capturedImage);
                  Uint8List imageTmp = await uiImage2Uint8List(capturedImage);
                  ImageAnalysisResult result =
                      objectDetection!.analyseImageUI(imageTmp);
                  image = drawResult(imageTmp, result);

                  setState(() {});
                },
                child: const Text('Analyze'),
              ),
            ),
            const SizedBox(height: 16.0),
            if (videoPath == null && videoUrl == null)
              ElevatedButton(
                onPressed: selectVideo,
                child: const Expanded(
                  child: Text('Select Video Files'),
                ),
              ),
            if (videoPath == null && videoUrl != null)
              ElevatedButton(
                onPressed: playVideoFromUrl,
                child: const Expanded(
                  child: Text('Play Video'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}