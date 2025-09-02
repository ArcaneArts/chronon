from __future__ import annotations

from typing import TYPE_CHECKING, Any

import numpy as np
from PIL import Image as PILImage
import io
import platform

from unstructured.documents.elements import ElementType
from unstructured.logger import logger, trace_logger
from unstructured.partition.utils.constants import Source
from unstructured.partition.utils.ocr_models.ocr_interface import OCRAgent
from unstructured.utils import requires_dependencies

if TYPE_CHECKING:
    from unstructured_inference.inference.elements import TextRegion, TextRegions
    from unstructured_inference.inference.layoutelement import LayoutElements


class OCRAgentApple(OCRAgent):
    """OCR service implementation for Apple Vision framework."""

    def __init__(self, language: str = "en"):
        self.languages = ["en-US"] if language == "en" else [language]  # Basic mapping; extend as needed
        self.agent = self.load_agent(language)

    def load_agent(self, language: str):
        """Loads the Apple Vision dependencies and checks platform."""

        if platform.system() != "Darwin":
            raise RuntimeError("Apple Vision framework is only available on macOS.")

        logger.info(f"Loading Apple Vision OCR on language={language}...")

        try:
            from AppKit import NSData, NSBitmapImageRep
            from Quartz import CIImage
            from Vision import (
                VNImageRequestHandler,
                VNRecognizeTextRequest,
                VNRecognizeTextRequestRecognitionLevelAccurate,
            )
        except ImportError:
            raise ImportError(
                "PyObjC dependencies for Vision not installed. Install with "
                "'pip install pyobjc-framework-Vision pyobjc-framework-Quartz pyobjc-framework-AppKit'"
            )

        # No agent instance needed; return None
        return None

    def get_text_from_image(self, image: PILImage.Image) -> str:
        ocr_regions = self.get_layout_from_image(image)
        return "\n\n".join(ocr_regions.texts)

    def is_text_sorted(self):
        return False

    def get_layout_from_image(self, image: PILImage.Image) -> TextRegions:
        """Get the OCR regions from image as a list of text regions with Apple Vision."""

        trace_logger.detail("Processing entire page OCR with Apple Vision...")

        # Convert PIL Image to CIImage
        data = io.BytesIO()
        image.save(data, "JPEG")
        nsdata = NSData.dataWithBytes_length_(data.getvalue(), len(data.getvalue()))
        rep = NSBitmapImageRep.imageRepWithData_(nsdata)
        ciimage = CIImage.imageWithBitmapImageRep_(rep)

        # Create request handler
        from Vision import VNImageRequestHandler, VNRecognizeTextRequest
        handler = VNImageRequestHandler.alloc().initWithCIImage_options_(ciimage, None)

        # Create text recognition request
        request = VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLevel_(VNRecognizeTextRequest.VNRecognizeTextRequestRecognitionLevelAccurate)
        request.setUsesLanguageCorrection_(True)
        request.setRecognizedLanguages_(self.languages)

        # Perform the request
        error_ptr = handler.performRequests_error_([request], None)
        if error_ptr[1] is not None:
            raise RuntimeError(f"Error performing Vision request: {error_ptr[1]}")

        ocr_data = request.results()
        ocr_regions = self.parse_data(ocr_data, image)

        return ocr_regions

    @requires_dependencies("unstructured_inference")
    def get_layout_elements_from_image(self, image: PILImage.Image) -> LayoutElements:
        ocr_regions = self.get_layout_from_image(image)

        # NOTE: For Apple Vision, similar to Paddle, no grouping difference
        return LayoutElements(
            element_coords=ocr_regions.element_coords,
            texts=ocr_regions.texts,
            element_class_ids=np.zeros(len(ocr_regions.texts)),
            element_class_id_map={0: ElementType.UNCATEGORIZED_TEXT},
        )

    @requires_dependencies("unstructured_inference")
    def parse_data(self, ocr_data: Any, image: PILImage.Image) -> TextRegions:
        """Parse the OCR result data to extract a list of TextRegion objects from Apple Vision.

        Parameters:
        - ocr_data: List of VNRecognizedTextObservation objects
        - image: The original PIL Image for coordinate conversion

        Returns:
        - TextRegions object
        """

        from unstructured_inference.inference.elements import TextRegions
        from unstructured.partition.pdf_image.inference_utils import build_text_region_from_coords

        text_regions: list[TextRegion] = []
        width, height = image.size

        for observation in ocr_data:
            if not observation:
                continue

            recognized_text = observation.topCandidates_(1)[0]
            text = recognized_text.string()
            if not text:
                continue
            cleaned_text = text.strip()
            if cleaned_text:
                bbox = observation.boundingBox()
                x1 = bbox.origin.x * width
                y1 = height * (1 - bbox.origin.y - bbox.size.height)  # Flip y-coordinate (Vision y=0 at bottom)
                x2 = x1 + bbox.size.width * width
                y2 = y1 + bbox.size.height * height
                text_region = build_text_region_from_coords(
                    x1, y1, x2, y2, text=cleaned_text, source=Source.OCR_APPLE  # Add OCR_APPLE to constants.py
                )
                text_regions.append(text_region)

        return TextRegions.from_list(text_regions)