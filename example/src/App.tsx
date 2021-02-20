import React, { useEffect, useState } from 'react'
import {
  SafeAreaView,
  StyleSheet,
  ScrollView,
  View,
  StatusBar,
  Image,
  Text,
  TouchableOpacity,
  Dimensions,
  Platform,
  UIManager,
  LayoutAnimation,
} from 'react-native'

import * as ImagePicker from 'react-native-image-picker'
import UploadManager, { StartUploadArgs } from 'react-native-upload-manager'


if (
  Platform.OS === "android" &&
  UIManager.setLayoutAnimationEnabledExperimental
) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

const d = Dimensions.get('window')
const isIphoneX =
  Platform.OS === 'ios' && (d.height > 800 || d.width > 800) ? true : false

declare type Tab = 'list' | 'queue'
declare type State = 'not_uploaded' | 'in_progress' | 'failed' | 'uploaded'
declare type UploadList = {
  [key: string]: UploadItem
}
declare type UploadItem = {
  uri: string
  progress: number
  state: State
}

const App = () => {
  const [uploadList, setUploadList] = useState<UploadList>({})
  const [uploadQueue, setUploadQueue] = useState<UploadList>({})
  const [tab, setTab] = useState<Tab>('list')

  useEffect(() => {
    const progressSubscription = UploadManager.addListener(
      'progress',
      (data: any) => {
        if (data && uploadList[data.id]) {
          const q: UploadList = {
            ...uploadList,
          }

          q[data.id] = {
            ...q[data.id],
            progress: data.progress,
            state: 'in_progress',
          }

          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
          
          setUploadList(q)
        } else if (data && uploadQueue[data.id]) {
          const q: UploadList = {
            ...uploadQueue,
          }

          q[data.id] = {
            ...q[data.id],
            progress: data.progress,
            state: 'in_progress',
          }

          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

          setUploadQueue(q)
        }
      }
    )
    const completeSubscription = UploadManager.addListener(
      'completed',
      (data: any) => {
        if (data && uploadList[data.id]) {
          const q: UploadList = {
            ...uploadList,
            [data.id]: {
              ...uploadList[data.id],
              state: 'uploaded',
            },
          }

          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

          setUploadList(q)
        } else if (data && uploadQueue[data.id]) {
          const q: UploadList = {
            ...uploadQueue,
            [data.id]: {
              ...uploadQueue[data.id],
              state: 'uploaded',
            },
          }

          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

          setUploadQueue(q)
        }
      }
    )
    const errorSubscription = UploadManager.addListener(
      'error',
      (data: any) => {
        if (data && uploadList[data.id]) {
          const q: UploadList = {
            ...uploadList,
            [data.id]: {
              ...uploadList[data.id],
              state: 'failed',
            },
          }

          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

          setUploadList(q)
        }
        if (data && uploadQueue[data.id]) {
          const q: UploadList = {
            ...uploadQueue,
            [data.id]: {
              ...uploadQueue[data.id],
              state: 'failed',
            },
          }
          
          // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

          setUploadQueue(q)
        }
      }
    )
    return () => {
      progressSubscription.remove()
      completeSubscription.remove()
      errorSubscription.remove()
    }
  }, [uploadList, uploadQueue])

  const uploadItem = async (uri: string, type?: string) => {
    try {
      const options: StartUploadArgs = {
        path: uri,
        method: 'POST',
        headers: {
          'content-type': type,
        },
        url: 'http://speedtest.tele2.net/upload.php',
        type: 'multipart',
        field: 'file',
        maxRetries: 0,
        notification: {
          enabled: true,
          onErrorMessage: 'upload failed',
          onCompleteMessage: 'upload success',
          onProgressMessage: 'uploading...  ([[PROGRESS]])',
          autoClear: true,
        },
      }

      if (tab == 'list') {
        const uploadId = await UploadManager.startUpload(options)
        const q: UploadList = {
          ...uploadList,
        }
        q[uploadId] = { uri, progress: 0, state: 'not_uploaded' }

        // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
        
        setUploadList(q)
      } else {
        const uploadId = await UploadManager.addToUploadQueue(options)
        const q: UploadList = {
          ...uploadQueue,
        }
        q[uploadId] = { uri, progress: 0, state: 'not_uploaded' }

        // LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);

        setUploadQueue(q)
      }
    } catch (error) {}
  }

  const onPressButton = async () => {
    ImagePicker.launchImageLibrary(
      {
        mediaType: 'photo',
      },
      (response) => {
        if (response.uri) uploadItem(response.uri, response.type)
      }
    )
  }

  return (
    <>
      <StatusBar barStyle='dark-content' backgroundColor='white' />
      <Header setTab={setTab} currentTab={tab} />
      <SafeAreaView style={styles.container}>
        <ScrollView contentInsetAdjustmentBehavior='automatic'>
          <View>
            <View style={styles.sectionContainer}>
              <UploadListView list={tab == 'list' ? uploadList : uploadQueue} />
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
      <TouchableOpacity onPress={onPressButton} style={styles.button}>
        <Text style={{ color: 'white' }}>Pick and Upload Image</Text>
      </TouchableOpacity>
    </>
  )
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#f1f1f1',
    flex: 1,
  },
  sectionContainer: {
    padding: 16,
  },

  item: {
    width: '100%',
    marginVertical: 8,
    flexDirection: 'column',
    backgroundColor: 'white',
  },
  itemContent: {
    flex: 1,
    margin: 12,
  },
  itemTopSection: {
    width: '100%',
    flex: 1,
    justifyContent: 'space-between',
    flexDirection: 'row',
    alignItems: 'center',
  },
  itemImage: { width: 50, height: 50 },
  itemProgressSection: {
    marginTop: 12,
    backgroundColor: '#dadada',
    height: 5,
  },
  itemProgressBar: {
    backgroundColor: '#2396f3',
    height: 5,
  },
  radius: {
    borderRadius: 4,
    overflow: 'hidden',
  },
  button: {
    paddingBottom: isIphoneX ? 20 : 0,
    height: 60 + (isIphoneX ? 20 : 0),
    backgroundColor: '#2396f3',
    width: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.2,
    shadowRadius: 1.41,
    elevation: 2,
    backgroundColor: 'white',
    paddingTop: isIphoneX ? 30 : 0,
    height: 100 + (isIphoneX ? 30 : 0),
    width: '100%',
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: 16,
    marginHorizontal: 16,
    ...Platform.select({ ios: { textAlign: 'center' } }),
  },
  headerTab: {
    flex: 1,
    borderBottomColor: '#2396f3',
    justifyContent: 'center',
    alignItems: 'center',
  },
})

export default App

const UploadItemView = React.memo(({ data }: { data: UploadItem }) => {
  return (
    <View style={[styles.item, styles.radius]}>
      <View style={styles.itemContent}>
        <View style={styles.itemTopSection}>
          <View style={[styles.itemImage, styles.radius]}>
            <Image
              resizeMode='cover'
              source={{ uri: data.uri }}
              style={{ width: '100%', height: '100%' }}
            ></Image>
          </View>
          <Text
            style={{
              color:
                data.state == 'not_uploaded'
                  ? 'gray'
                  : data.state == 'failed'
                  ? 'red'
                  : data.state == 'uploaded'
                  ? 'green'
                  : 'black',
            }}
          >
            {data.state == 'not_uploaded'
              ? 'Pending'
              : data.state == 'failed'
              ? 'Failed'
              : data.state == 'uploaded'
              ? 'Success'
              : `${data.progress}%`}
          </Text>
        </View>
        {data.state == 'in_progress' && (
          <View style={[styles.itemProgressSection, styles.radius]}>
            <View
              style={[styles.itemProgressBar, { width: `${data.progress}%` }]}
            ></View>
          </View>
        )}
      </View>
    </View>
  )
})

const UploadListView = React.memo(({ list }: { list: UploadList }) => {
  return (
    <>
      {Object.keys(list).map((key) => {
        const item = list[key]
        return <UploadItemView key={key} data={item} />
      })}
    </>
  )
})

const Header = ({
  currentTab,
  setTab,
}: {
  currentTab: Tab
  setTab: (tab: Tab) => any
}) => {
  return (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>Upload Manager</Text>
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <TouchableOpacity
          onPress={() => setTab('list')}
          style={[
            styles.headerTab,
            { borderBottomWidth: currentTab == 'list' ? 3 : 0 },
          ]}
        >
          <Text>List</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => setTab('queue')}
          style={[
            styles.headerTab,
            { borderBottomWidth: currentTab == 'queue' ? 3 : 0 },
          ]}
        >
          <Text>Queue</Text>
        </TouchableOpacity>
      </View>
    </View>
  )
}
