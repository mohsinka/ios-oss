import AVFoundation
import AVKit
import Library
import LiveStream
import Prelude
import UIKit

import ReactiveSwift
import Result

internal protocol LiveStreamDiscoveryLiveNowCellViewModelInputs {
  func configureWith(liveStreamEvent: LiveStreamEvent)
}

internal protocol LiveStreamDiscoveryLiveNowCellViewModelOutputs {
  var creatorImageUrl: Signal<URL?, NoError> { get }
  var creatorLabelText: Signal<String, NoError> { get }
  var playVideoUrl: Signal<URL?, NoError> { get }
  var streamImageUrl: Signal<URL?, NoError> { get }
  var streamTitleLabel: Signal<String, NoError> { get }
}

internal protocol LiveStreamDiscoveryLiveNowCellViewModelType {
  var inputs: LiveStreamDiscoveryLiveNowCellViewModelInputs { get }
  var outputs: LiveStreamDiscoveryLiveNowCellViewModelOutputs { get }
}

internal final class LiveStreamDiscoveryLiveNowCellViewModel: LiveStreamDiscoveryLiveNowCellViewModelType,
LiveStreamDiscoveryLiveNowCellViewModelInputs, LiveStreamDiscoveryLiveNowCellViewModelOutputs {

  internal init() {
    let liveStreamEvent = self.configData.signal.skipNil()

    self.creatorImageUrl = liveStreamEvent
      .map { URL(string: $0.creator.avatar) }

    self.playVideoUrl = liveStreamEvent
      .switchMap { event in
        AppEnvironment.current.liveStreamService.fetchEvent(eventId: event.id, uid: nil)
          .demoteErrors()
          .prefix(value: event)
          .map { $0.hlsUrl.map(URL.init(string:)) }
          .skipNil()
          .take(first: 1)
    }

    self.creatorLabelText = liveStreamEvent
      .map { Strings.Creator_name_is_live_now(creator_name: $0.creator.name) }

    self.streamTitleLabel = liveStreamEvent
      .map { $0.name }

    self.streamImageUrl = liveStreamEvent
      .map { URL.init(string: $0.backgroundImage.medium) }
  }

  private let configData = MutableProperty<LiveStreamEvent?>(nil)
  internal func configureWith(liveStreamEvent: LiveStreamEvent) {
    self.configData.value = liveStreamEvent
  }

  internal let creatorImageUrl: Signal<URL?, NoError>
  internal let creatorLabelText: Signal<String, NoError>
  internal let playVideoUrl: Signal<URL?, NoError>
  internal let streamImageUrl: Signal<URL?, NoError>
  internal let streamTitleLabel: Signal<String, NoError>

  internal var inputs: LiveStreamDiscoveryLiveNowCellViewModelInputs { return self }
  internal var outputs: LiveStreamDiscoveryLiveNowCellViewModelOutputs { return self }
}

internal final class LiveStreamDiscoveryLiveNowCell: UITableViewCell, ValueCell {
  private let viewModel: LiveStreamDiscoveryLiveNowCellViewModelType = LiveStreamDiscoveryLiveNowCellViewModel()

  @IBOutlet private weak var cardView: UIView!
  @IBOutlet private weak var creatorImageView: UIImageView!
  @IBOutlet private weak var creatorLabel: SimpleHTMLLabel!
  @IBOutlet private weak var creatorStackView: UIStackView!
  @IBOutlet private weak var imageOverlayView: UIView!
  @IBOutlet private weak var liveContainerView: UIView!
  @IBOutlet private weak var liveLabel: UILabel!
  @IBOutlet private weak var streamImageView: UIImageView!
  @IBOutlet private weak var streamPlayerView: AVPlayerView!
  @IBOutlet private weak var streamTitleContainerView: UIView!
  @IBOutlet private weak var streamTitleLabel: UILabel!
  @IBOutlet private weak var topGradientView: GradientView!

  internal func configureWith(value: LiveStreamEvent) {
    self.viewModel.inputs.configureWith(liveStreamEvent: value)
  }

  internal override func bindStyles() {
    super.bindStyles()

    self.streamPlayerView.layer.contentsGravity = AVLayerVideoGravityResizeAspectFill

    _ = self
      |> baseTableViewCellStyle()
      |> UITableViewCell.lens.contentView.layoutMargins %~~ { insets, cell in
        cell.traitCollection.isVerticallyCompact
          ? .init(top: Styles.grid(2), left: insets.left * 6, bottom: Styles.grid(4), right: insets.right * 6)
          : .init(top: Styles.grid(2), left: insets.left, bottom: Styles.grid(4), right: insets.right)
    }

    _ = self.cardView
      |> cardStyle()
      |> dropShadowStyle()

    _ = self.creatorLabel
      |> SimpleHTMLLabel.lens.boldFont .~ UIFont.ksr_title3(size: 14).bolded
      |> SimpleHTMLLabel.lens.baseFont .~ UIFont.ksr_title3(size: 14)
      |> SimpleHTMLLabel.lens.baseColor .~ .white
      |> SimpleHTMLLabel.lens.numberOfLines .~ 0

    _ = self.liveContainerView
      |> roundedStyle()
      |> UIView.lens.backgroundColor .~ .ksr_green_500
      |> UIView.lens.layoutMargins .~ .init(topBottom: Styles.gridHalf(1), leftRight: Styles.gridHalf(3))

    _ = self.liveLabel
      |> UILabel.lens.text .~ Strings.Live()
      |> UILabel.lens.textColor .~ .white
      |> UILabel.lens.font .~ .ksr_title3(size: 13)
      |> UILabel.lens.numberOfLines .~ 0

    _ = self.streamTitleContainerView
      |> UIView.lens.layoutMargins .~ .init(topBottom: Styles.grid(2), leftRight: Styles.grid(3))

    _ = self.streamTitleLabel
      |> UILabel.lens.font .~ .ksr_title3(size: 15)
      |> UILabel.lens.textColor .~ .ksr_text_navy_900
      |> UILabel.lens.numberOfLines .~ 0

    _ = self.streamImageView
      |> UIImageView.lens.clipsToBounds .~ true

    _ = self.imageOverlayView
      |> UIView.lens.backgroundColor .~ UIColor.black.withAlphaComponent(0.4)

    _ = self.creatorStackView
      |> UIStackView.lens.spacing .~ Styles.grid(1)

    self.topGradientView.startPoint = .init(x: 0, y: 0)
    self.topGradientView.endPoint = .init(x: 0, y: 1)
    self.topGradientView.setGradient(
      [
        (UIColor.black.withAlphaComponent(0.6), 0),
        (UIColor.black.withAlphaComponent(0), 1)
      ]
    )
  }

  internal override func bindViewModel() {
    super.bindViewModel()

    self.creatorImageView.rac.imageUrl = self.viewModel.outputs.creatorImageUrl
    self.creatorLabel.rac.html = self.viewModel.outputs.creatorLabelText

    self.viewModel.outputs.playVideoUrl
      .observeForUI()
      .observeValues { [weak self] in self?.loadVideo(url: $0) }

    self.streamImageView.rac.imageUrl = self.viewModel.outputs.streamImageUrl
    self.streamTitleLabel.rac.text = self.viewModel.outputs.streamTitleLabel
  }

  private func loadVideo(url: URL?) {
    self.streamPlayerView.alpha = 0

    self.streamPlayerView.playerLayer?.player = url.map(AVPlayer.init(url:))
    self.streamPlayerView.playerLayer?.player?.play()
    self.streamPlayerView.playerLayer?.player?.isMuted = true

    UIView.animate(withDuration: 0.3) {
      self.streamPlayerView.alpha = 1
    }
  }
}
