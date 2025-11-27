# 테크, 기획, 디자인 설명

Date: November 28, 2025

# Overview

> 통상적으로 **추억을 회상**하기 위한 최선의 방식을 묻는다면 **사진과 영상**이다. 
**시각적 요소를 이용하는 데에 어려움을 겪는 시각장애인은 어떨까?** 
컴퓨터 비전 기술을 통해 사진을 읽어주는 등의 접근성 기술이 있지만 충분하지 않다. 
이에 **Audiolog는 Apple의 기술을 이용해 추억 회상의 접근성을 갖추고자 시작되었다.**

* **접근성**이란 장애 유무, 성별, 나이, 지식 수준 등과 관계없이 **누구나 불편함 없이 쉽고 편리하게 접근하고 이용할 수 있는 정도**를 의미한다.
> 

## Tech

### **1. 공간 음향**

1. **공간 음향(Spatial Audio)**: 기존의 좌우를 구분해주는 스테레오(Stereo) 방식에서 더 나아가 소리가 **360도 사방에서 들리게 하는 3차원 오디오 기술**이다.
Apple 공간음향의 가장 큰 특징은 **동적 머리 추적(Dynamic Head Tracking)**에 있다. AirPods 사용자와 디바이스 스크린의 방향을 비교해, 사용자가 움직이더라도 실제 해당 공간에 있는 것처럼 소리의 발생 위치를 일정하게 유지한다.
2. **공간 음향 녹음**: iPhone 15 Pro 모델 이상부터, 공간 음향 녹음을 제공한다. 이때 음향 버퍼는 **X, Y, Z 좌표와 W(전체 음압)**의 정보를 가진다.
Audiolog는 스테레오 음향으로 목소리의 선명함을, 공간 음향으로 현장의 공감감을 동시에 포착하는 **동시 녹음 전략**을 채택했다.
    
    ![스크린샷 2025-11-26 오후 11.57.51.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-26_%E1%84%8B%E1%85%A9%E1%84%92%E1%85%AE_11.57.51.png)
    

### **2. 5단계 분석 파이프라인**

Audiolog는 녹음이 완료된 후 해당 기록을 5단계에 거쳐 분석한다. 여기에는 **애플의 자체 프레임워크 및 온디바이스 모델이 사용되어 사용자의 프라이버시와 안정성을 보장**한다.

1. **음성 인식(Speech-to-Text)**: Apple의 **Speech** 프레임워크를 활용했다. Speech 프레임워크에서는 온디바이스, 서버사이드 두 가지의 STT모델을 모두 지원한다.
Audiolog는 **온디바이스 모델만을 활용해 감지된 음성을 텍스트로 정리**한다.
2. **소리 분류(Sound Classification)**: Apple에서 제공하는 **Sound Analysis** 모델을 활용했다. Sound Analysis는 오디오 기록에서 비언어적 소리를 300개 전후의 클래스로 분류한다.
Audiolog는 **confidence가 가장 높고 0.7이상인 결과값 3개**를 메타데이터로 저장한다.
3. **음악 인식(Music Recognition)**: Apple의 **ShazamKit** 프레임워크를 활용했다. Audiolog는 해당 공간의 배경음악을 감지해 제목 생성에 최우선적인 정보로 반영한다.
4. **메타데이터 추가**: Apple의 **CoreLocation**, **Weather**등의 프레임워크를 활용했다. Audiolog는 위치, 장소, 날씨, 시간등의 데이터를 추가한다.
5. **AI를 활용한 제목 생성**: Apple의 온디바이스 LLM인 **Foundation Models**를 활용했다. Foundation Models는 유저의 시스템에 이미 저장되어있는 모델을 활용해 세션만 생성하는 방식으로 앱의 용량 부담을 전혀 주지 않는다.
Audiolog에서는 이전 4단계에서 생성된 데이터들을 Foundation Models를 활용해, 30자 이내의 한국어 제목으로 요약한다.
단순히 "2025년 11월 26일 녹음"보다는 **"비 오는 날 카페에서, NewJeans의 노래가 흐르고, 친구와 웃으며 대화한 기록"**으로 제목이 생성되는 것을 목표로 한다.
    
    ![스크린샷 2025-11-27 오전 12.12.53.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_12.12.53.png)
    

### **3. 2단계 검색 파이프라인**

Audiolog는 2단계의 검색 파이프라인을 통해, 기성 녹음 앱의 탐색 과정을 압축한다.

1. **키워드 포함 검색**: 일반적인 검색 기능과 같다. 제목에 유저가 입력한 검색어가 포함되어 있다면 결과에 추가한다.
2. **AI를 활용한, 검색어 대 기록데이터 유사도 검색**: 제목에 검색어를 포함하지 않은 기록이라면 기록이 가진 메타데이터와 검색어의 관련도를 FoundationModels을 통해 비교한다.

### **4. FoundationModels 사용 전략**

이때 FoundationModels를 사용에 있어 두 가지 유의할 점이 있다. 
FoundationModels을 사용할 시 LanguageModelSession을 생성하게 되는데 같은 Session을 공유하는 요청은 같은 맥락을 유지하려 한다. 이에 있어 개별적인 요청임에도 불구하고 이전 요청 혹은 응답의 영향을 받게 된다. 개발자라면 비합리적으로 느껴지겠지만, 맥락이 필요한 요청이 아니라면 매 요청마다 Session을 새로 생성하는 것이 좋다. 이미 FoundationModels 프레임워크 내부적으로 이에 대해 최적화돼 있기 때문이다.

또 하나의 유의할 점은, 지시사항이나 정보를 상세히 전달하는 것보다 **최대한으로 절제된 정보를 전달하는 편의 결과물이 더 좋다**는 것이다. 이는 LM의 **Attention** 개념에서 기인한다. 온디바이스 모델은 경량화의 이유로 기성 서버사이드 모델보다 중요하지 않은 정보를 구분할 수 있는 여유가 적기 때문에, 중요하지 않은 정보에도 필요 이상의 Attention이 할당될 확률이 높다. 따라서 LM에 모든 걸 맡기기보다는 입력 prompt를 조절하는 전처리 과정을 거치는 게 좋다. 

![스크린샷 2025-11-27 오전 12.27.10.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_12.27.10.png)

- **English ver.**
    
    ### 1. Spatial Audio
    
    **Spatial Audio** is a **3D audio technology** that goes beyond the traditional stereo method (which distinguishes left and right) to allow **sound to be heard from 360 degrees around the user.**
    
    The most significant feature of Apple Spatial Audio is **Dynamic Head Tracking**. By comparing the orientation of the AirPods user with the device screen, it maintains a consistent sound source location even when the user moves, creating the sensation that the user is actually present in that space.
    
    1. **Spatial Audio Recording:** Starting with the iPhone 15 Pro models, spatial audio recording is supported. In this process, the audio buffer contains information for **X, Y, and Z** coordinates as well as W (omnidirectional sound pressure).
    2. **Audiolog** has adopted a **simultaneous** recording strategy: it captures vocal clarity using stereo audio while simultaneously capturing the spatial presence of the environment using spatial audio.
    
    ![스크린샷 2025-11-26 오후 11.57.51.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-26_%E1%84%8B%E1%85%A9%E1%84%92%E1%85%AE_11.57.51.png)
    
    ---
    
    ### 2. 5-Stage Analysis Pipeline
    
    After recording is complete, Audiolog analyzes the record through a 5-stage process. This utilizes **Apple’s native frameworks and on-device models to ensure user privacy and stability.**
    
    1. **Speech-to-Text:** Utilizes Apple’s **Speech framework**. While the Speech framework supports both on-device and server-side STT models, Audiolog exclusively uses the **on-device model to transcribe detected speech into text.**
    2. **Sound Classification:** Utilizes Apple’s **Sound Analysis model**. This model classifies non-verbal sounds from the audio record into approximately 300 different classes. Audiolog saves **the top 3 results that have a confidence score of 0.7 or higher** as metadata.
    3. **Music Recognition:** Utilizes Apple’s **ShazamKit framework**. Audiolog detects background music in the space and prioritizes this information when generating the title.
    4. **Adding Metadata:** Utilizes Apple’s **CoreLocation** and **Weather** frameworks. Audiolog appends data such as location, venue, weather, and time.
    5. **AI-Powered Title Generation:** Utilizes Apple’s on-device LLM, **Foundation Models**. By using models already stored on the user’s system and only generating a session, it places no storage burden on the app. Audiolog uses Foundation Models to summarize the data generated in the previous four stages into a concise title (under 30 characters).
        - *Goal:* Instead of a simple "Recorded on Nov 26, 2025," the goal is to generate a descriptive title like **"Rainy day at a cafe, listening to NewJeans, laughing with a friend."**
        
        ![스크린샷 2025-11-27 오전 12.12.53.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_12.12.53.png)
        
    
    ---
    
    ### 3. 2-Stage Search Pipeline
    
    Audiolog streamlines the browsing process of conventional recording apps through a 2-stage search pipeline.
    
    1. **Keyword Inclusion Search:** Similar to standard search functions. If the user’s search query is included in the title, it is added to the results.
    2. **AI-Powered Similarity Search:** If the search query is not found in the title, **Foundation Models** are used to compare the relevance between the record’s metadata and the search query.
    
    ---
    
    ### 4. Strategy for Using Foundation Models
    
    There are two key points to consider when using Foundation Models.
    
    First, using Foundation Models involves creating a **LanguageModelSession**. Requests sharing the same Session attempt to maintain the same context. Consequently, even independent requests can be influenced by previous requests or responses. While this may seem counterintuitive to developers, it is better to create a new Session for every request unless context is strictly necessary. The Foundation Models framework is already internally optimized for this approach.
    
    Second, providing **restrained, concise information yields better results** than providing detailed instructions or excessive data. This stems from the concept of **Attention** in Large Language Models (LLMs). Because on-device models are lightweight, they have less capacity to distinguish unimportant information compared to full-scale server-side models. This leads to a higher probability of assigning unnecessary Attention to irrelevant data. Therefore, rather than leaving everything to the LM, it is advisable to perform a pre-processing step to optimize the input prompt.
    
    ![스크린샷 2025-11-27 오전 12.27.10.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_12.27.10.png)
    

## Design & Accesibility

### Desk Research

<aside>

📌 **Insight**

시각장애인에게 **소리는 기억을 떠올리고 경험을 재구성하는 핵심 단서**로 작동하며, 

비시각장애인이 사진으로 추억을 기록하듯 **시각장애인은 소리로 순간을 저장하고 다시 경험**한다.

</aside>

**‘다른 사람들이 눈으로 볼 때 나는 귀로 본다’** [🔗](http://www.ydp-welfare.or.kr/bbs/board.php?bo_table=0402&wr_id=1444)

> 연구에 참가한 시각장애인 중 한 명이 **‘다른 사람들이 눈으로 볼 때 나는 귀로 본다’**고 말한 것처럼 
이번 연구가 시각장애인들이 세상을 어떻게 이해하는지 설명해 줄 것”이라고 말했다.
> 

> 연구팀은 **시각장애인이 비장애인보다 청각 신호의 움직임을 따라가는 능력도 높다**는 것을 밝혔다.
연구팀은 시각적으로 물체를 추적할 때 활성화되는 뇌의 영역인 hMT+에 주목해 소리가 나는 물체를 움직이고
뇌의 반응을 살피는 실험을 했다. 시각장애인은 소리가 움직이면 hMT+가 활성화됐다.
반면 비장애인은 hMT+가 전혀 활동하지 않았다.
> 

**‘인생샷’ 대신 ‘인생 소리’ 남기는 사람들** [🔗](https://news.sbs.co.kr/news/endPage.do?news_id=N1004689415)

> “시각장애인 친구들하고만 일본에 온천 여행을 갔었어요. 
아직도 **그때 녹음해온 파일을 같이 들으면서 몇 시간씩 계속 얘기해요.**”
> 

> 시각장애인들의 여행에서 무엇보다 중요한 것은 **'소리'**입니다. 
사진도 찍지만, **여행지의 소리를 녹음해 파일로 만들어 여행 추억을 간직**합니다.
"사진도 많이 찍지만, 아무래도 소리로 남기는 게 더 와닿고 편하더라고요."
이렇게 남긴 **'인생 소리'를 여행 추억을 되새기고 싶을 때 다시 듣곤 합니다.**
> 

**지금까지의 회상 연구는 모두, 비시각장애인만을 위한 연구였다.** [🔗](https://community.dbpia.co.kr/en/article/348)

> “**알다시피 우리에게는 사진이 없어요. 사진을 볼 수도 없고요.** 제 남동생은 병으로 2012년에 세상을 떠났는데, 얼마 후에 조카가 유튜브에 동영상을 올렸더라고요. 거기에는 남동생의 목소리가 담겨 있었어요. 정말 감동이었어요. **그 목소리를 들으니까, 동생과 함께한 기억들이 생생하게 떠올랐어요.** 신기하죠? 목소리가 그를 기억하는 데 큰 도움이 됐어요.”
> 

> 지나간 시간을 추억하는 일은 삶을 살아가는 데 있어 중요한 역할을 한다. **긍정적이고 행복한 기억을 떠올리는 습관은 스트레스로 인한 행동 장애나 우울증을 완화하는 데 도움을 준다**는 연구도 있지만 (Ramirez et al., 2015), 이러한 **과학적 근거와는 별개로 사랑하는 사람을 그리워하거나, 소중한 순간을 다시 느끼기 위해, 혹은 지나간 시간을 애도하고 기억하기 위해 자연스럽게 과거를 돌아본다.**
> 

> HCI 분야에서도 일상, 소유물, 특별한 경험 등을 통해 과거를 회상하게 하는 연구들이 활발하게 이루어지고 있지만, **지금까지 대부분의 회상 관련 연구는 비시각장애인을 전제로 설계되고 진행**되어 왔다.
물론, 시각장애인을 대상으로 하는 연구는 이전부터 활발히 이루어져 왔고, 지금도 계속되고 있다. 하지만 대부분은 이동성(mobility & navigation), 위치 추적(location & position tracking), 접근성(accessibility) 등 **일상생활에서의 실질적인 불편함을 새로하려는 목적의 보조공학(assistive technology)**에 초점을 맞추고 있다.
> 

> 효율성과 실용성을 위한 기술적 지원 목적 외에, **시각장애인의 일상에 밀접한 ”인간적인 가치”를 중심으로 한 연구는 아직까지 많이 이루어지고 있지 않다.** 이러한 맥락에서, **“과거 회상”이라는 감정적이고 개인적인 경험**을 **시각장애인의 관점에서 듣고, 이해하고, 함께 관찰하며**, 또 그들이 지닌 소유물이나 디지털 데이터를 활용해 과거를 추억하는 경험에 대한 연구는 아직까지 HCI 분야에서는 한 번도 진행된 적이 없었다.
> 

---

### User Research

<aside>

📌 **Insight**

**순차적 탐색에 의존**하는 시각장애인은 현재의 기록 방식에서는 분류·검색이 어려워 추억을 회상하기
힘들기 때문에, **익숙한 배치 구조**와 더불어 **간단하고 접근 가능한 검색·분류 기능**이 필수적이다.

</aside>

![실로암 시각장애 복지관 인터뷰](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/IMG_5079.jpeg)

실로암 시각장애 복지관 인터뷰

🔍 **앱 사용 행동 관찰 결과**

- **순차 탐색 중심**: 위→아래, 왼쪽→오른쪽 순서로 훑으며 탐색
- 화면 구성은 시각적 배치보다 **탐색 순서의 논리적 구조화**가 더 중요
- **모서리나 외부 영역부터 탐색:** 삭제나 더보기 버튼은 외곽부 배치가 인식에 도움
- **2손가락 탭**(기본 보이스오버 제스처)로 재생/일시정지를 주로 수행
- 검색은 **위나 오른쪽 아래쪽**에서 탐색 시작

📝 **추억 기록 관련 인터뷰 결과**

- “산책을 하다가 특이한 소리가 나오면, 예를들어 새 서식지가 나타난 것 같다면 녹음을 해요.”
- “녹음한 기록을 종종 다시 들어요. **다시 들으려고 녹음을 하는거에요.**”
- “지역 이름만으로는 찾기가 힘들어서 바로 **녹음 제목을 구체적으로 수정**해요.”
- “물이 흐르는 **방향이 느껴지는** 소리를 다시 들을 수 있으면 좋을 것 같아요”

---

### 1. 접근성 전략: 카메라를 대체하는 즉각적 경험 (Zero-Latency Capture)

iOS 생태계에서 사용자가 **가장 빠르게 실행할 수 있는 앱은 단연 '카메라'**입니다. 찰나의 순간을 시각적으로 포착하기 위함입니다. **Audiolog**는 **시각이 아닌 '청각'으로 그 순간을 포착**합니다. 따라서 카메라에 버금가는 **진입 속도**가 필수적이었습니다.

- **QuickAction(잠금화면 위젯):** 잠금 해제 과정을 생략하고, 잠금 화면에서 즉시 앱을 실행 및 녹음을 시작할 수 있도록 설계해 사용자가 기억하고 싶은 순간을 놓치지 않게 했습니다.
    
    ![image.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/image.png)
    

### 2. 디자인 원칙: '전용'이 아닌 '보편'을 지향하다 (Universal Design)

초기에는 시각장애인을 위해 가시성이 극대화된 전용 UI를 고려했습니다. 그러나 실사용자 심층 인터뷰 결과는 예상과 달랐습니다.

- **Insight:** 전맹 시각장애인이 선호하는 앱은 '시각장애인 전용 앱'이 아니라 '배달의민족', '카카오톡', '유튜브'와 같은 **대중적인 기성 앱**이었습니다. **VoiceOver 지원만 충실하다면, 기성 앱의 사용성에 큰 문제가 없다**는 의견이 지배적이었습니다. 심지어 "개발자에게 직접 연락해 접근성 개선을 요청한다"는 적극적인 피드백도 있었습니다.
- **Decision:** 우리는 '장애인을 위한다'는 명분으로 **낯선 구조를 강요하는 것이 오히려 새로운 학습 비용을 초래**한다고 판단했습니다. 따라서 Apple의 HIG(Human Interface Guidelines)를 준수하여, **비장애인과 장애인 모두에게 익숙한 표준 인터페이스를 채택**했습니다.

### 3. VoiceOver 최적화를 위한 UI 구조 개선 (Flat Hierarchy)

'리퀴드 글래스(Liquid Glass)' 디자인이 적용된 최신 iOS 환경에서의 VoiceOver 경험을 분석한 결과, 심미성이 접근성을 저해하는 두 가지 문제점을 발견했습니다.

**1) 계층(Z-Index) 중첩으로 인한 탐색 오류**
리퀴드 글래스 디자인 특성상 Toolbar나 Tabbar가 반투명한 플로팅 형태로 콘텐츠 위에 겹쳐지는 경우가 많습니다.

- **Problem:** 시각적으로는 아름답지만, VoiceOver 커서가 플로팅 UI 아래에 깔린 콘텐츠를 인식하지 못하거나, 사용자가 ScrollView를 끝없이 탐색해야 하는 내비게이션 트랩이 발생했습니다.
- **Solution:** Audiolog는 리퀴드 글래스의 **심미성은 유지**하되, VoiceOver가 인식하는 **논리적 구조는 평면적인 계층으로 설계**하여 모든 콘텐츠에 명확하게 도달할 수 있도록 했습니다.
    
    ![스크린샷 2025-11-27 오전 2.47.07.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.47.07.png)
    

**2) 유기적 레이아웃 변화의 예측 불가능성**
음악 앱 등에서 흔히 보이는, 하단 플레이어가 전체 화면(Bottom Sheet)으로 확장되는 유기적인 인터랙션은 시각장애인에게 혼란을 줍니다.

- **Problem:** 화면의 맥락이 급격하게 변할 때, 시각적 단서가 없는 사용자는 현재 위치를 놓치게 됩니다.
- **Solution:** 우리는 바텀 액세서리가 화면 전체를 덮으며 확장되는 방식을 배제하고, 예측 가능한 화면 전환 방식을 채택했습니다.
    
    ![스크린샷 2025-11-27 오전 2.27.43.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.27.43.png)
    

### 4. 미니 플레이어(Global Media Control)의 재정의

앱 어디서나 접근 가능한 '미니 플레이어'는 필수 요소였지만, 앞서 언급한 접근성 문제(계층 및 크기 제한)를 해결해야 했습니다.

- **Standardization:** 독자적인 UI 대신 iOS 시스템 전반에서 통용되는 **Music Controller**의 표준 레이아웃을 차용해 익숙함을 제공했습니다.
- **VoiceOver 'Magic Tap':** 시각적 요소는 최소화(Minimize)하되, VoiceOver의 핵심 기능인 **매직 탭(Magic Tap, 두 손가락 두 번 탭)** 기능을 완벽하게 지원하여, 보지 않고도 재생/정지를 제어할 수 있는 사용성을 보장했습니다.
    
    ![스크린샷 2025-11-27 오전 2.33.17.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.33.17.png)
    

- **English ver.**
    
    ### Desk Research
    
    <aside>
    
    📌 **Insight**
    
    For the visually impaired, **sound serves as a critical cue for recalling memories and reconstructing experiences**. Just as sighted individuals preserve memories through photographs, the **visually impaired store and relive moments through sound.**
    
    </aside>
    
    **"When others see with their eyes, I see with my ears"** [🔗](http://www.ydp-welfare.or.kr/bbs/board.php?bo_table=0402&wr_id=1444)
    
    > One participant in the study stated, **"When others see with their eyes, I see with my ears,"** highlighting how the research explains the unique way visually impaired individuals perceive the world.
    > 
    
    > The research team revealed that **the visually impaired possess a heightened ability to track the movement of auditory signals compared to sighted individuals.** The study focused on the **hMT+** region of the brain, which is typically activated when visually tracking objects. Experiments monitoring brain response to moving sound sources showed that the **hMT+ region was activated in visually impaired participants** in response to auditory motion. In contrast, the hMT+ region in sighted participants remained inactive during the same tasks.
    > 
    
    **Capturing "Life Sounds" instead of "Life Shots"** [🔗](https://news.sbs.co.kr/news/endPage.do?news_id=N1004689415)
    
    > "I went on a hot spring trip to Japan with my visually impaired friends. **We still listen to the audio files recorded back then and talk for hours.**"
    > 
    
    > For the visually impaired, the most critical element of travel is **'Sound.'** While they do take photos, they **cherish their travel memories by creating audio files of the environment.**
    "We take a lot of photos, but recording sounds feels more resonant and comfortable for us." **They revisit these "Life Sounds" whenever they want to reminisce about their travels.**
    > 
    
    **Reminiscence research has been exclusive to the sighted.** [🔗](https://community.dbpia.co.kr/en/article/348)
    
    > "**As you know, we don't have photos. We can't see them.** My younger brother passed away in 2012, and later my nephew uploaded a video to YouTube. It contained my brother's voice. It was truly touching. **Hearing his voice brought back vivid memories of our time together.** It's fascinating, isn't it? His voice was a massive help in remembering him."
    > 
    
    > Reminiscing about the past plays a vital role in life. While studies show that **the habit of recalling positive and happy memories helps alleviate behavioral disorders or depression caused by stress** (Ramirez et al., 2015), **apart from scientific evidence, humans naturally look back to miss loved ones, relive precious moments, or mourn.**
    > 
    
    > In the field of **HCI (Human-Computer Interaction)**, research on recalling the past through daily life, possessions, and special experiences is active. However, **most reminiscence-related research has been designed and conducted exclusively for the sighted.**
    > 
    > 
    > Of course, research targeting the visually impaired has been active and ongoing. However, most of it focuses on **Assistive Technology** aimed at resolving practical inconveniences in daily life, such as **mobility & navigation, location & position tracking, and accessibility.**
    > 
    
    > Beyond technical support for efficiency and practicality, **research centered on "Human Values" close to the daily lives of the visually impaired is still lacking**. In this context, HCI research that listens to, understands, and observes the emotional and personal experience of **"Reminiscence"** from the perspective of the visually impaired—and how they use possessions or digital data to cherish the past—has essentially never been conducted.
    > 
    
    ---
    
    ### User Research
    
    <aside>
    
    📌 **Insight**
    
    Since visually impaired users rely on **sequential navigation**, current recording methods make categorization and retrieval difficult, hindering the recall of memories. Therefore, a **familiar layout structure** combined with **simple and accessible search & categorization features** is essential.
    
    </aside>
    
    ![실로암 시각장애 복지관 인터뷰](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/IMG_5079.jpeg)
    
    실로암 시각장애 복지관 인터뷰
    
    ### 🔍 Observation of App Usage Behavior
    
    - **Sequential Navigation Focus:** Users scan and navigate in a specific order: **Top → Bottom, Left → Right**.
    - **The logical structuring of the navigation order** is far more critical than the aesthetic or visual arrangement of the screen.
    - **Perimeter Exploration:** Users often start exploring from the corners or outer edges. Placing functional buttons like "Delete" or "More" in the **peripheral areas** aids recognition.
    - **Standard Gesture Reliance:** The **2-finger tap** (standard VoiceOver gesture) is the primary method used for Play/Pause commands.
    - **Search Patterns:** Search actions typically originate from the **top** or the **bottom-right** sections of the screen.
    
    ### 📝 Interview Results on Recording Memories
    
    > "If I hear a unique sound while taking a walk—for instance, if it sounds like I've found a bird habitat—I record it immediately."
    > 
    
    > "I often listen to my recordings again. That’s the whole reason I record them—**to listen back.**"
    > 
    
    > "It's hard to find files just by the location name, so I immediately **rename the title to something specific.**"
    > 
    
    > "It would be great if I could listen to sounds where I can **feel the direction**, like the flow of water."
    > 
    
    ---
    
    ### 1. Accessibility Strategy: An Instant Experience to Replace the Camera (Zero-Latency Capture)
    
    In the iOS ecosystem, the fastest app a user can launch is undoubtedly the **Camera**. It exists to visually capture fleeting moments. **Audiolog** **captures those moments through auditory means, not visual ones.** Therefore, achieving an entry speed comparable to the camera was essential.
    
    - **QuickAction (Lock Screen Widget):** We designed the app to skip the unlocking process, allowing users to launch the app and start recording immediately from the lock screen so they never miss a moment they want to remember.
        
        ![image.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/image.png)
        
    
    ### 2. Design Principle: Aiming for 'Universal,' Not 'Exclusive' (Universal Design)
    
    Initially, we considered a "high-visibility exclusive UI" for the visually impaired. However, in-depth user interviews revealed a different reality.
    
    - **Insight:** Users with total blindness preferred popular mainstream apps like **Baedal Minjok (food delivery), KakaoTalk, and YouTube** over "apps exclusively for the visually impaired." The dominant opinion was that **as long as VoiceOver support is robust, there are no significant issues with using standard apps.** Some users even mentioned actively contacting developers to request accessibility improvements.
    - **Decision:** We determined that forcing an unfamiliar structure under the guise of "helping the disabled" actually incurs new **learning costs**. Therefore, we adhered to **Apple's HIG (Human Interface Guidelines)** and adopted a **standard interface familiar to both non-disabled and disabled users.**
    
    ### 3. UI Structure Improvements for VoiceOver Optimization (Flat Hierarchy)
    
    Analyzing the VoiceOver experience in the modern iOS environment with **"Liquid Glass"** design revealed two major issues where aesthetics hindered accessibility.
    
    **1) Navigation Errors Due to Layering (Z-Index) Overlap**
    In Liquid Glass design, toolbars or tabbars often float semi-transparently over content.
    
    - **Problem:** While visually beautiful, this created **"navigation traps"** where the VoiceOver cursor failed to recognize content beneath the floating UI, or users had to scroll endlessly to find information.
    - **Solution:** **While maintaining the aesthetic of Liquid Glass,** Audiolog designed the **logical structure** recognized by VoiceOver to be a **flat hierarchy**, ensuring clear access to all content.
        
        ![스크린샷 2025-11-27 오전 2.33.17.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.33.17.png)
        
    
    **2) Unpredictability of Organic Layout Changes**
    The organic interaction often seen in music apps, where the bottom player expands into a full screen (Bottom Sheet), causes confusion for visually impaired users.
    
    - **Problem:** When the screen context changes abruptly, users without visual cues lose their current position.
    - **Solution:** We rejected the method where the bottom accessory expands to cover the entire screen and instead adopted a **predictable screen transition** method.
    
    ![스크린샷 2025-11-27 오전 2.27.43.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.27.43.png)
    
    ### 4. Redefining the Mini Player (Global Media Control)
    
    A "Mini Player" accessible from anywhere in the app was essential, but we needed to solve the accessibility issues (layering and size limitations) mentioned above.
    
    - **Standardization:** Instead of a unique UI, we adopted the standard layout of the **Music Controller** commonly used across the iOS system to provide familiarity.
    - **VoiceOver 'Magic Tap':** While minimizing visual elements, we fully supported the **Magic Tap** (two-finger double tap), a core VoiceOver feature. This ensures usability that allows users to control play/pause without looking at the screen.
    
    ![스크린샷 2025-11-27 오전 2.33.17.png](%ED%85%8C%ED%81%AC,%20%EA%B8%B0%ED%9A%8D,%20%EB%94%94%EC%9E%90%EC%9D%B8%20%EC%84%A4%EB%AA%85/%E1%84%89%E1%85%B3%E1%84%8F%E1%85%B3%E1%84%85%E1%85%B5%E1%86%AB%E1%84%89%E1%85%A3%E1%86%BA_2025-11-27_%E1%84%8B%E1%85%A9%E1%84%8C%E1%85%A5%E1%86%AB_2.33.17.png)
