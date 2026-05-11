# Mahjong Utility
해당 프로젝트는 마작을 즐길 때 유용한 기능들을 넣은 앱입니다.


## 미리보기
![메인화면](https://github.com/HaYeongJIN/Mahjong-Utility/blob/development/image/Screenshot_20260510_205137.jpg)

![대기패분석](https://github.com/HaYeongJIN/Mahjong-Utility/blob/development/image/Screenshot_20260330_162116.jpg)

![디지털전탁](https://github.com/HaYeongJIN/Mahjong-Utility/blob/development/image/Screenshot_20260510_205141.jpg)
## 주요 기능
### 1. 점수 계산
상단에 도라, 하단에 손패를 화면에 밎춰 찍으면 점수를 계산해줍니다.
### 2. 대기패 분석
손패를 화면에 맞춰 찍으면 화료패를 알려줍니다.
### 3. 디지털 전탁
손탁으로 게임 진행 시 도움되는 점수표시, 화료, 유국등의 기능을 제공합니다.

## 다운로드
https://github.com/HaYeongJIN/Mahjong-Utility/releases/tag/v1.0.0

## 기술 스택
### Frontend
* Framework: Flutter(Dart)
* Platform: Android(minSdkversion 21)
* On-Device ML: Tensorflow Lite(YOLOv11 -> TFlite 경량화)

### Core Logic
* Language: Rust
* Rust [Agari](https://github.com/rysb-dev/agari) 라이브러리를 사용하여 점수계산 및 대기패 분석을 진행합니다.

### Machine Learning
* Model: YOLOv11
* Environment: Google Colab(Python으로 데이터셋 학습)

## Dataset
기존 오픈 데이터셋과 부족한 데이터를 직접 촬영하여 추가했습니다.

* [Open datasets](https://universe.roboflow.com/project-xv49e/mahjong-x5dzz)
* Custom datasets: 부족한 뒷면 데이터셋과 적도라패들을 직접 촬영하여 추가했습니다.
